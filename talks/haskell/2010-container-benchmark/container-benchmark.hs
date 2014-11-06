{-# LANGUAGE
    ExistentialQuantification
  , ScopedTypeVariables
  , RecordWildCards
  , KindSignatures
  , FlexibleContexts #-}
import Data.IORef
import Control.Applicative
import Control.Monad
import Control.Exception
import Control.Arrow
import System.IO
import System.Random.Mersenne

import qualified Data.Map      as Map
import qualified Data.IntMap   as IntMap
import qualified Data.Sequence as Seq
import Data.Array.IO
import Data.Array.IArray
import Data.Array.Unboxed
import Data.Array.Diff
import qualified Data.Vector                 as Vector
import qualified Data.Vector.Mutable         as MVector
import qualified Data.Vector.Unboxed         as UVector
import qualified Data.Vector.Unboxed.Mutable as UMVector
import qualified Data.Vector.Generic         as GVector
import qualified Data.Vector.Generic.Mutable as GMVector
import qualified Control.Monad.Primitive     as Prim
import qualified Data.Judy as Judy

import qualified Criterion      as Cri
import qualified Criterion.Main as Cri

data P1 (a :: *      -> *) = P1
data P2 (a :: * -> * -> *) = P2

data IContainer k v = forall c. IContainer
  { icEmpty  :: c
  , icLookup :: k -> c -> Maybe v
  , icInsert :: k -> v -> c -> c }

icFun :: (Eq k) => IContainer k v
icFun = IContainer
  { icEmpty  = const Nothing
  , icLookup = flip ($)
  , icInsert = \k v f x -> if x==k then Just v else f x }

icAssocList :: (Eq k) => IContainer k v
icAssocList = IContainer
  { icEmpty  = []
  , icLookup = Prelude.lookup
  , icInsert = \k v -> ((k,v):) }

icMap :: (Ord k) => IContainer k v
icMap = IContainer
  { icEmpty  = Map.empty
  , icLookup = Map.lookup
  , icInsert = Map.insert }

icIntMap :: IContainer Int v
icIntMap = IContainer
  { icEmpty  = IntMap.empty
  , icLookup = IntMap.lookup
  , icInsert = IntMap.insert }

icSeq :: Int -> v -> IContainer Int v
icSeq len fill = IContainer
  { icEmpty  = Seq.replicate len fill
  , icLookup = \k   a -> Just (Seq.index a k)
  , icInsert = \k v a -> Seq.update k v a }

icIArray :: forall a k v. (Ix k, IArray a v) =>
  P2 a -> (k, k) -> v -> IContainer k v
icIArray _ bnd fill = IContainer
  { icEmpty  = listArray bnd (repeat fill) :: (a k v)
  , icLookup = \k   a -> Just (a ! k)
  , icInsert = \k v a -> a // [(k,v)] }

icIVector :: forall v x. (GVector.Vector v x) =>
  P1 v -> Int -> x -> IContainer Int x
icIVector _ len fill = IContainer
  { icEmpty  = GVector.replicate len fill :: v x
  , icLookup = \k   a -> Just (a GVector.! k)
  , icInsert = \k v a -> a GVector.// [(k,v)] }

data MContainer m k v = forall c. MContainer
  { mcNew    :: m c
  , mcLookup :: k -> c -> m (Maybe v)
  , mcInsert :: k -> v -> c -> m () }

mcUsingIORef :: IContainer k v -> MContainer IO k v
mcUsingIORef (IContainer{..}) = MContainer
  { mcNew    = newIORef icEmpty
  , mcLookup = \k   c -> icLookup k <$> readIORef c
  , mcInsert = \k v c -> do
      cv  <- readIORef c
      cv' <- evaluate $ icInsert k v cv
      writeIORef c cv' }

mcMArray
  :: forall m a k v.
     (Ix k, MArray a v m)
  => P2 a -> (k, k) -> v -> MContainer m k v
mcMArray _ bnd fill = MContainer
  { mcNew    = newArray bnd fill :: m (a k v)
  , mcLookup = \k   a -> Just `liftM` readArray a k
  , mcInsert = \k v a -> writeArray a k v }

mcMVector :: forall v x. (GMVector.MVector v x) =>
  P2 v -> Int -> x -> MContainer IO Int x
mcMVector _ len fill = MContainer
  { mcNew    = GMVector.newWith len fill :: IO (v Prim.RealWorld x)
  , mcLookup = \k   a -> Just `liftM` GMVector.read a k
  , mcInsert = \k v a -> GMVector.write a k v }

mcJudy :: (Judy.JE v) => MContainer IO Int v
mcJudy = MContainer
  { mcNew    = Judy.new
  , mcLookup = Judy.lookup . fromIntegral
  , mcInsert = Judy.insert . fromIntegral }

keyRange, valueRange :: Int
keyRange   = 10000
valueRange = maxBound

numInserts, numLookups :: Int
numInserts = 5000
numLookups = 5000

test :: MTGen -> MContainer IO Int Int -> IO ()
test gen (MContainer{..}) = do
  c <- mcNew
  replicateM_ numInserts (testInsert c)
  replicateM_ numLookups (testLookup c)
  where
    randomN n = (`mod` n) <$> random gen
    testInsert c = do
      k <- randomN keyRange
      v <- randomN valueRange
      mcInsert k v c
    testLookup c = do
      k <- randomN keyRange
      v <- mcLookup k c
      evaluate v

containers :: [(String, MContainer IO Int Int)]
containers = map (second mcUsingIORef)
  [("function",    icFun),
   ("assoc list",  icAssocList),
   ("Map",         icMap),
   ("IntMap",      icIntMap),
   ("Seq",         icSeq keyRange 0),
   ("Array",       ia (P2 :: P2 Array           )),
   ("UArray",      ia (P2 :: P2 UArray          )),
   ("DiffArray",   ia (P2 :: P2 DiffArray       )),
   ("DiffUArray",  ia (P2 :: P2 DiffUArray      )),
   ("Vector",      iv (P1 :: P1 Vector.Vector   )),
   ("UVector",     iv (P1 :: P1 UVector.Vector  ))] ++
  [("IOArray",     ma (P2 :: P2 IOArray         )),
   ("IOUArray",    ma (P2 :: P2 IOUArray        )),
   ("IOVector",    mv (P2 :: P2 MVector.MVector )),
   ("IOUVector",   mv (P2 :: P2 UMVector.MVector)),
   ("judy",        mcJudy)]
  where
    ia x = icIArray  x (0, keyRange-1) 0
    ma x = mcMArray  x (0, keyRange-1) 0
    iv x = icIVector x keyRange 0
    mv x = mcMVector x keyRange 0

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  mt <- newMTGen Nothing
  Cri.defaultMain $ map (\(n,c) -> Cri.bench n $ test mt c) containers

window.addEventListener('load', function () {
    // Put each <h1> and subsequent content into its own <section>.
    function makeSections(node) {
        var sections = [];
        while (true) {
            sections.push(document.createElement('section'));
            var section = sections[sections.length - 1];
            var sib;
            while (true) {
                sib = node.nextSibling;
                if (sib === null) {
                    section.appendChild(node);
                    return sections;
                }
                if (sib.nodeName === 'H1') {
                    break;
                }
                section.appendChild(node);
                node = sib;
            }
            node = sib;
        }
    }

    var title = document.getElementsByClassName('title')[0];
    [].forEach.call(makeSections(title), function (x) {
        document.body.appendChild(x);
    });

    var sections = document.getElementsByTagName('section');
    var current = 0;
    var view_all = false;
    function update() {
        [].forEach.call(sections, function (x, i) {
            x.className = view_all ? 'show' : '';
            if (i === 0) {
                x.className += ' title-slide';
            }
        });
        if (current < 0)
            current = 0;
        if (current >= sections.length)
            current = sections.length - 1;
        if (!view_all) {
            sections[current].className += ' show';
        }
    }

    update();

    document.body.addEventListener('keydown', function (ev) {
        switch (ev.keyCode) {
            case 39: current++; break;
            case 37: current--; break;
        }
        update();
    });

    document.body.className = 'noscroll';

    var view_all_link = document.getElementById('view-all');
    if (view_all_link !== null) {
        view_all_link.addEventListener('click', function (e) {
            view_all = true;
            update();
            document.body.className = '';
            e.preventDefault();
        });
    }
});

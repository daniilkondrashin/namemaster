document.addEventListener('DOMContentLoaded', function () {
    const HISTORY_BUTTON = document.querySelector('.header__history');
    const HISTORY_MENU = document.querySelector('.history-menu');
    const HISTORY_MENU_CLOSE = document.querySelector('.menu__header-icon')

    HISTORY_BUTTON.addEventListener('click', function() {
        HISTORY_MENU.classList.add('history-menu-visible');
    })

    HISTORY_MENU_CLOSE.addEventListener('click', function() {
        HISTORY_MENU.classList.remove('history-menu-visible');
    })

    document.addEventListener('click', function (e) {
        const isClickInHISTORY_BUTTON = HISTORY_BUTTON.contains(e.target);
        const isClickInHISTORY_MENU = HISTORY_MENU.contains(e.target);

        if (!isClickInHISTORY_BUTTON && !isClickInHISTORY_MENU) {
            HISTORY_MENU.classList.remove('history-menu-visible');
        }
    })
})
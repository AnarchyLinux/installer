const header = document.querySelector("header");

function paddingHeader() {
    document.body.style.paddingTop = `${header.offsetHeight}px`;
}

window.addEventListener("load", paddingHeader);
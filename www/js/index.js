const folders = document.querySelectorAll('.folder');
folders.forEach(folder => {
    folder.addEventListener('click', (e) => {
        e.stopPropagation();
        folder.classList.toggle('active');
    });
});

const files = document.querySelectorAll('.file');
const descBox = document.getElementById('descBox');

files.forEach(file => {
    file.addEventListener('click', (e) => {
        e.stopPropagation();
        const desc = file.getAttribute('data-desc');
        const link = file.getAttribute('data-link');
        descBox.innerHTML = `${desc} <br><a href="${link}" target="_blank">Open File</a>`;
    });
});
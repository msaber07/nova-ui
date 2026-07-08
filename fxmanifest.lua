fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nova-ui'
author 'Nova'
description 'Standalone Nova UI: notifications, confirm, progress and document cards'
version '1.0.0'

shared_scripts {
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

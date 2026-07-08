Config = Config or {}

-- Language: 'tr' or 'en'
Config.Locale = 'en'

-- Sound configuration: Play synthesized UI sound effects
Config.PlaySounds = true

-- Document card default brand. It can be overridden during the call.
Config.Brand = {
    badge = 'N', -- document card badge (short, 1-2 letters)
    footer = 'Roleplay', -- document card alt text
}

Config.Locales = {
    en = {
        -- Notification category titles (used if no title is given)
        toneTitles = {
            primary = 'INFO',
            info    = 'INFO',
            success = 'SUCCESS',
            error   = 'ERROR',
            warning = 'WARNING',
        },
        confirmTitle   = 'Confirm',
        accept         = 'Accept',
        reject         = 'Decline',
        progressLabel  = 'Working...',
        documentKicker = 'DOCUMENT',
        documentTitle  = 'Document',
        
        -- New components
        submit         = 'Submit',
        cancel         = 'Cancel',
        menuBack       = 'Go Back',
        inputRequired  = 'This field is required',
    },
    tr = {
        toneTitles = {
            primary = 'BILGI',
            info    = 'BILGI',
            success = 'BASARILI',
            error   = 'HATA',
            warning = 'DIKKAT',
        },
        confirmTitle   = 'Onay',
        accept         = 'Kabul Et',
        reject         = 'Reddet',
        progressLabel  = 'Islem...',
        documentKicker = 'BELGE',
        documentTitle  = 'Belge',
        
        -- New components
        submit         = 'Gönder',
        cancel         = 'İptal',
        menuBack       = 'Geri Dön',
        inputRequired  = 'Bu alan zorunludur',
    },
}

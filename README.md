# PwshPaint

While procrastinating about setting up my blog I wanted to create a favicon in a pixel art style. Instead of creating the icon I got carried away spaghetti coding a pixel art editor for the terminal in PowerShell...

# Installation
```pwsh
Install-Module PwshPaint
Import-Module PwshPaint
```

# Usage

## Editor

To open the editor use:
```pwsh
Invoke-Paint
```

All controls are indicated in the UI:  
![image](https://user-images.githubusercontent.com/13159458/198860063-efdc62b9-4524-4a5a-b9ec-55855469bf7f.png)
_(If you prefer Vim-style hjkl keys to navigate instead of arrows you can use `Invoke-Paint -VimBindings`)_  

## Gallery

```pwsh
Invoke-PaintGallery
```
![image](https://user-images.githubusercontent.com/13159458/190280363-71d602c8-35a5-4aa8-8ad2-f9c41ece9c62.png)

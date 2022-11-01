# PwshPaint

[![GitHub license](https://img.shields.io/github/license/ShaunLawrie/PwshPaint)](https://github.com/ShaunLawrie/PwshPaint/blob/main/LICENSE)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PwshPaint)](https://www.powershellgallery.com/packages/PwshPaint)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PwshPaint)](https://www.powershellgallery.com/packages/PwshPaint)
[![Build](https://img.shields.io/github/workflow/status/ShaunLawrie/PwshPaint/Pester%20Test)](https://github.com/ShaunLawrie/PwshPaint/actions/workflows/test.yml)

While procrastinating about setting up my blog I wanted to create a favicon in a pixel art style. Instead of creating the icon I got carried away spaghetti coding a pixel art editor for the terminal in PowerShell...

# Installation
```pwsh
Install-Module PwshPaint -Scope CurrentUser
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
![image](https://user-images.githubusercontent.com/13159458/198866053-a1e1dc78-6e98-4fe8-bd36-830f5a6ce48a.png)

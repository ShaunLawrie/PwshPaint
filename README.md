# PwshSprites

While procrastinating about setting up my blog I wanted to create a favicon in a pixel art style. Instead of creating the icon I got carried away spaghetti coding a pixel art editor for the terminal in PowerShell...

To open the editor run `./PwshEditor.ps1`  
The editor controls are all indicated in the UI apart from pressing [SPACE] to draw pixels and arrow keys to move. Snake mode will make the pen or eraser constantly apply changes as you navigate the canvas.
![image](https://user-images.githubusercontent.com/13159458/190280318-bc757f47-74e8-4b25-b40b-166f95131c23.png)

To open the viewer run `./PwshViewer.ps1`  
This will start a PowerShell web server and open a page showing all of the images in the sprites folder. There is a problem with ctrl-c being caught in the terminal so sometimes you need to close the window to stop the web server. I think using a background job would stop this occurring but I haven't tried it yet.
![image](https://user-images.githubusercontent.com/13159458/190280363-71d602c8-35a5-4aa8-8ad2-f9c41ece9c62.png)

#SimArchive

![SimArchive screenshot](https://fouquet.me/content/3-apps/4-simarchive/simarchive.png)
SimArchive makes it easy to distribute iOS Simulator builds of your apps. It lets you import and export apps from iOS Simulator devices (iOS 8 and up), including their respective Documents/Library/Caches directories. Just select the right iOS version and the device the app is (or should be) installed in. SimArchive then shows you a list of all the apps currently present on the device and lets you export or import them with one click. Exported apps can be distributed and installed on other machines, used as snapshot of the current app state or deployed to other Simulator devices on the same machine.

##Features:

* Import and export apps to or from iOS Simulator devices
* Start or restart the iOS Simulator with one click
* Quickly access the app’s respective Documents directory (double click on an app, or via right click contextual menu)
* Quickly access the app’s bundle file or remove it from the device (via right-click contextual menu)

##Requirements:
SimArchive requires at least OS X 10.9 (Mavericks) and Xcode 6.0.

##Getting it
If you don't want to compile it yourself, you can download a copy on my [website](https://fouquet.me/apps/simarchive/). This binary is developer ID signed and can receive updates via Sparkle.

##Compiling it
To compile SimArchive, you need to change three things:

* In Build Settings, set the *Code Signing Identity* to your own. Or change the *Team* in General.
* In Build Phases, there is a run script build phase which signs the Sparkle Framework. You need to change the *IDENTITY* variable to you own Developer ID.
* In the *Info.plist* file, change the *SUFeedURL* key to your own Sparkle instance (or leave it empty). Otherwise official updates of SimArchive will confuse the hell out of Sparkle and potentially break the binary because it is not signed with my key.

##Credits

Third party libraries are integrated via CocoaPods and checked into this repo. For detailed license information, see the Acknowledgments.rtf file.

* [DCOAboutWindow](https://github.com/DangerCove/DCOAboutWindow) by Danger Cove
* [VDKQueue](https://github.com/bdkjones/VDKQueue) by Bryan D K Jones 
* [Sparkle](https://github.com/sparkle-project/Sparkle) by The Sparkle Project

##Author

René Fouquet, mail@fouquet.me

Check out my blog: [fouquet.me](https://fouquet.me)

Follow me on Twitter at @renefouquet

##License
RFAboutView is available under the MIT license. See the LICENSE file for more info.
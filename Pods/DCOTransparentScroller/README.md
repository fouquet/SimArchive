# Overview

DCOTransparentScroller introduces a track-less `NSScrollView` and `NSScroller`.

It mimics the default appearance when a trackpad or magic mouse is used.

# Setup

## Via [cocoapods](http://cocoapods.org)

I'll add the pod to the cocoapods library. As soon as it's accepted you can use:

    pod 'DCOTransparentScroller'

While it hasn't been added add the following line to your Podfile:

    pod 'DCOTransparentScroller', :git => 'git@github.com:DangerCove/DCOTransparentScroller.git'

Then run `pod install` and you're set.

## Manually

Clone this repo and add files from `DCOTransparentScroller` to your project.

# Usage

Open your nib in Interface Builder. Select the `NSScrollview` and change its class to `DCOTransparentScrollView`. Select both `NSScroller`s and change their class to `DCOTransparentScroller`.

# Known Issues

It's not perfect and there are some cases where it glitches.

# Contributions and things to add

Reduce glitching ;).

# License

New BSD License, see `LICENSE` for details.

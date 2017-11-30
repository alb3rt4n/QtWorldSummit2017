import QtQuick 2.0

/*
  Input properties are height and locale. Width is set automatically to match the image aspect ratio.

 */
Image {
  //id: countryImage

  property string locale

  // NOTE: gameNetworkItem is only available if used in children from the GameNetworkView, e.g. from the MatchMakingView
  source: {

    if(!locale)
      return ""
    if(typeof(gameNetworkItem) !== "undefined")
      return gameNetworkItem.getFlagUrlFromLocale(locale)
    if(typeof(gameNetwork) !== "undefined")
      return gameNetwork.getFlagUrlFromLocale(locale)
    return ""

    // for testing how different flags look like
  //      var randomNumber = Math.ceil(utils.generateRandomValueBetween(0,6))
  //      console.debug("randomNumber:", randomNumber)
  //      // if no locale is set, also dont display a flag
  //      if(!locale || randomNumber == 0)
  //        return ""
  //      if(randomNumber == 1)
  //        return "https://v-play.net/gamenetwork/flags/96x64/BE.png"
  //      if(randomNumber == 2)
  //        return "https://v-play.net/gamenetwork/flags/96x64/AT.png"
  //      if(randomNumber == 3)
  //        return "https://v-play.net/gamenetwork/flags/96x64/US.png"
  //      if(randomNumber == 4)
  //        return "https://v-play.net/gamenetwork/flags/96x64/CA.png"
  //      if(randomNumber == 5)
  //        return "https://v-play.net/gamenetwork/flags/96x64/CH.png"
  //      return ""

  }

  // the original flags have size 96*64, which is a 1.5 multiplication difference; thus use the same ratio here
  width: height * 1.5
  //fillMode: Image.PreserveAspectFit // it looks better if the flags are scaled so they have the same size and not keep the original aspect ratio; mostly visible e.g. at the swiss flag
  //horizontalAlignment: Image.AlignRight // has no effect

  // but does not need to be set here - if the countryCodeEnabled is false, then we never have a locale set anyway! -> not true, if the player did upload a locale before, it is set and will then be displayed when the FlagImage is known in game code
  // in that case, explicitly disable it with UserImage.displayFlagImage
  // we could add it with the typeof check here, then at least it would be disabled in the MatchMakingView and other views within the GameNetworkView
  //visible: (typeof(countryCodeEnabled) !== "undefined" && countryCodeEnabled) && locale // can be globally disabled in the GameNetworkView - no general access to countryCodeEnabled from here
}

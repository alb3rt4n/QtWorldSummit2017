import VPlayApps 1.0
import QtQuick 2.0
import VPlay 2.0 // for game network
import VPlayPlugins 1.0 // for NotificationManager
import QtGraphicalEffects 1.0
import "pages"
import "common"

Item {
  anchors.fill: parent

  // make navigation public
  property alias navigation: navigation

  // game network / multiplayer view (only once per app)
  property alias gameNetworkViewItem: gameNetworkViewItem //publicly accessible
  property alias multiplayerViewItem: multiplayerViewItem //publicly accessible

  Component.onCompleted: {
    buildPlatformNavigation()  // apply platform specific navigation changes
    if(system.publishBuild) {
      // give 1 point for opening the app
      if(gameNetwork.userScoresInitiallySynced)
        gameNetwork.reportRelativeScore(1)
      else
        gameNetwork.addScoreWhenSynced += 1
    }
    notificationTimer.start() // schedule notification at app-start
    checkFeedbackDialog() // check app starts and show feedback dialog
  }

  // handle data loading failed
  Connections {
    target: DataModel
    onLoadingFailed: NativeDialog.confirm("Failed to update conference data, please try again later.")
    onFavoriteAdded: {
      console.debug("favorite added")
      if(gameNetwork.userScoresInitiallySynced)
        gameNetwork.reportRelativeScore(1)
      else
        gameNetwork.addScoreWhenSynced += 1


      // only schedule a notification for the changed talk, not for all again
      scheduleNotificationForTalk(talk.id)

      amplitude.logEvent("Favor Talk",{"title" : talk.title, "talkId" : talk.id})
    }
    onFavoriteRemoved: {
      console.debug("favorite removed")
      if(gameNetwork.userScoresInitiallySynced && gameNetwork.userHighscoreForCurrentActiveLeaderboard > 0)
        gameNetwork.reportRelativeScore(-1)
      else if(!gameNetwork.userScoresInitiallySynced)
        gameNetwork.addScoreWhenSynced -= 1

      cancelNotificationForTalk(talk.id)

      amplitude.logEvent("Unfavor Talk",{"title" : talk.title, "talkId" : talk.id})
    }
    onFavoritesChanged: {
      // the schedule call is stopped below anyways, if the notificationTimer did not complete
      // with this check, we would not allow push not syncing if the user is offline, thus do not add this
      //if(!gameNetwork.userInitiallyInSync) {
      //  console.debug("favorties changed, but user is not synced with server yet thus wait")
      //  return
      //}

      console.debug("onFavoritesChanged")
      // dont reschedule all when favorites changed - they are scheduled indidividually instead as a complete reschedule is a lenghty operation
      //scheduleNotificationsForFavorites()
    }
    onNotificationsEnabledChanged: {
       console.debug("onNotificationsEnabledChanged, reschedule notifications")
      scheduleNotificationsForFavorites()
    }
  }

  // timer to schedule notifications several seconds after app startup
  Timer {
    id: notificationTimer
    interval: 8000 // we can delay this, is not time-critical to happen initially
    //running: true // start the timer when the compoent was loaded - it is started from onCompleted after the navigation was setup
    onTriggered: {
      console.debug("notificationTimer.triggered", running)
      scheduleNotificationsForFavorites()
    }
  }


  // scheduleNotificationsForFavorites
  function scheduleNotificationsForFavorites() {
    console.debug("attempting scheduleNotificationsForFavorites()")

    if(notificationTimer.running) {
      console.debug("notificationTimer at initialization is currently running, dont update yet")
      return
    }

    console.debug("scheduling notifications now")

    // TODO: only re-schedule, if the current nofications changed. this may be a lengthy process

    notificationManager.cancelAllNotifications()
    if(!DataModel.notificationsEnabled || !DataModel.favorites || !DataModel.talks)
      return

    for(var idx in DataModel.favorites) {
      var talkId = DataModel.favorites[idx]
      scheduleNotificationForTalk(talkId)
    }

    // add notification before world summit starts!
    var nowTime = new Date().getTime()
    var eveningBeforeConferenceTime = new Date("2017-10-09T21:00.000"+DataModel.timeZone).getTime()
    if(nowTime < eveningBeforeConferenceTime) {
      var text = "V-Play wishes all the best for Qt World Summit 2017!"
      var notification = {
        notificationId: -1,
        message: text,
        timestamp: Math.round(eveningBeforeConferenceTime / 1000) // utc seconds
      }
      notificationManager.schedule(notification)
    }
  }

  // scheduleNotificationForTalk
  function scheduleNotificationForTalk(talkId) {
    if(DataModel.loaded && DataModel.talks && DataModel.talks[talkId]) {
      var talk = DataModel.talks[talkId]
      var text = talk["title"]+" starts "+talk.start+" at "+talk["room"]+"."

      var nowTime = new Date().getTime()
      var utcDateStr = talk.day+"T"+talk.start+".000"+DataModel.timeZone
      var notificationTime = new Date(utcDateStr).getTime()
      notificationTime = notificationTime - 10 * 60 * 1000 // 10 minutes before

      if(nowTime < notificationTime) {
        var notification = {
          notificationId: talkId,
          message: text,
          timestamp: Math.round(notificationTime / 1000) // utc seconds
        }
        notificationManager.schedule(notification)
      }
    }
  }

  function cancelNotificationForTalk(talkId) {
    notificationManager.cancelNotification(talkId)
  }

  // handle theme switching (apply navigation changes)
  Connections {
    target: Theme
    onPlatformChanged: buildPlatformNavigation()
  }

  // app navigation
  Navigation {
    id: navigation
    property var currentPage: {
      if(!currentNavigationItem)
        return null

      if(currentNavigationItem.navigationStack)
        return currentNavigationItem.navigationStack.currentPage
      else
        return currentNavigationItem.page
    }

    // automatically load data if not loaded and schedule/favorites page is opened
    onCurrentIndexChanged: {
      if(currentIndex > 0 && currentIndex < 3) {
        if(!DataModel.loaded && isOnline)
          DataModel.loadData()
      }
    }
    onCurrentNavigationItemChanged: {
      amplitude.logEvent("Open Page",{"title" : currentNavigationItem.title})
    }

    // Android drawer header item
    headerView: Item {
      width: parent.width
      height: dp(75) + Theme.statusBarHeight
      clip: true

      Rectangle {
        anchors.fill: parent
        color: Theme.tintColor
      }

      AppImage {
        width: parent.width
        fillMode: AppImage.PreserveAspectFit
        source: "../assets/venue_photo.jpg"
        anchors.verticalCenter: parent.verticalCenter
      }

      AppImage {
        width: parent.width
        fillMode: AppImage.PreserveAspectFit
        source: "../assets/venue_photo.jpg"
        anchors.verticalCenter: parent.verticalCenter
        opacity: 0.5
        layer.enabled: true
        layer.effect: Colorize {
          id: titleImgColorize
          lightness: 0.1
          saturation: 0.5

          // we set the hue for the colorize effect based on the Theme.tintColor
          // this could be done with a simple property binding, but that strangely causes issues on Linux Qt 5.8
          // which is why this workaround with manual signal handling is used:
          property color baseColor
          Component.onCompleted: updateHue()
          Connections {
            target: app
            onSecondaryTintColorChanged: titleImgColorize.updateHue()
          }
          function updateHue() {
            titleImgColorize.baseColor = app.secondaryTintColor
            var hslColor = loaderItem.colorToHsl(titleImgColorize.baseColor)
            titleImgColorize.hue = hslColor[0]
            titleImgColorize.saturation = hslColor[1]
            titleImgColorize.lightness = hslColor[2]
          }
        }
      }

      AppImage {
        width: parent.width * 0.75
        source: "../assets/QtWS2017_logo_white.png"
        fillMode: AppImage.PreserveAspectFit
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.statusBarHeight + ((parent.height - Theme.statusBarHeight) - height) * 0.5
        layer.enabled: true
        layer.effect: DropShadow {
          color: Qt.rgba(0,0,0,0.5)
          radius: 16
          samples: 16
        }
      }
    }

    NavigationItem {
      title: "About"
      iconComponent: Item {
        height: parent.height
        width: height

        property bool selected: parent && parent.selected

        Icon {
          anchors.centerIn: parent
          width: height
          height: parent.height
          icon: IconType.home
          color: !parent.selected ? Theme.textColor  : Theme.tintColor
          visible: !vplayIcon.visible
        }

        Image {
          id: vplayIcon
          height: parent.height
          anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
          fillMode: Image.PreserveAspectFit
          source: !parent.selected ? (Theme.isAndroid ? "../assets/Qt_logo_Android_off.png" : "../assets/Qt_logo_iOS_off.png") : "../assets/Qt_logo.png"
          visible: Theme.isIos || Theme.backgroundColor.r == 1 && Theme.backgroundColor.g == 1 && Theme.backgroundColor.b == 1
        }
      }

      NavigationStack {
        navigationBarShadow: false
        MainPage {}
      }
    } // main

    NavigationItem {
      title: "Timetable"
      icon: IconType.calendaro

      NavigationStack {
        splitView: tablet && landscape
        // if first page, reset leftColumnIndex (may change when searching)
        onTransitionFinished: {
          if(depth === 1)
            leftColumnIndex = 0
        }

        TimetablePage {
          onFloatingButtonClicked: {
            navigation.currentIndex = 2
          }
        }
      }
    } // timetable

    NavigationItem {
      title: "Favorites"
      icon: IconType.star

      NavigationStack {
        splitView: tablet && landscape
        FavoritesPage {
          onFloatingButtonClicked: {
            navigation.currentIndex = 1
          }
        }
      }
    } // favorites

    NavigationItem {
      title: "Speakers"
      icon: IconType.microphone

      NavigationStack {
        splitView: landscape && tablet
        SpeakersPage {}
      }
    } // speakers
  } // nav

  // components for dynamic tabs/drawer entries
  Component {
    id: tracksNavItemComponent
    NavigationItem {
      title: "Tracks"
      icon: IconType.tag

      NavigationStack {
        splitView: landscape && tablet
        TracksPage {}
      }
    }
  } // tracks

  // components for dynamic tabs/drawer entries
  Component {
    id: venueNavItemComponent
    NavigationItem {
      title: "Venue"
      icon: IconType.building

      NavigationStack {
        VenuePage {}
      }
    }
  } // venue

  // component for contacts menu item
  Component {
    id: contactsNavItemComponent
    NavigationItem {
      title: "QR Contacts"
      icon: IconType.qrcode

      NavigationStack {
        ContactsPage {}
      }
    }
  } // contacts

  // components for dynamic tabs/drawer entries
  Component {
    id: settingsNavItemComponent
    NavigationItem {
      title: "Settings"
      icon: IconType.gears

      NavigationStack {
        SettingsPage {}
      }
    }
  } // settings

  // about v-play page
  Component {
    id: aboutVPlayNavItemComponent
    NavigationItem {
      title: "About V-Play"
      iconComponent: Item {
        height: parent.height
        width: height

        property bool selected: parent && parent.selected

        Icon {
          anchors.centerIn: parent
          width: height
          height: parent.height
          icon: IconType.home
          color: !parent.selected ? Theme.textColor  : Theme.tintColor
          visible: !vplayIcon.visible
        }

        Image {
          id: vplayIcon
          height: parent.height
          anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
          fillMode: Image.PreserveAspectFit
          source: !parent.selected ? "../assets/VPlay_icon_nav_off.png" : "../assets/VPlay_icon_nav.png"
          visible: Theme.isIos || Theme.backgroundColor.r == 1 && Theme.backgroundColor.g == 1 && Theme.backgroundColor.b == 1
        }
      }

      NavigationStack {
        AboutVPlayPage {}
      }
    }
  } // about v-play

  Component {
    id: moreNavItemComponent
    NavigationItem {
      title: "More"
      icon: IconType.ellipsish

      NavigationStack {
        splitView: tablet && landscape
        MorePage {}
      }
    }
  } // more

  // dummyNavItemComponent for adding gameNetwork/multiplayer pages to navigation (android)
  Component {
    id: dummyNavItemComponent
    NavigationItem {
      id: dummyNavItem
      title: "Leaderboard"
      icon: IconType.flagcheckered // gamepad, futbolo, group, listol. sortnumericasc

      property var targetItem
      property string targetState
      property var initHandler: function() { }

      NavigationStack {
        Page {
          id: dummyPage
          navigationBarHidden: true
          title: "DummyPage"

          NavigationBar {
            width: parent.width
          }

          property Item targetItem: dummyNavItem.targetItem
          property string targetState: dummyNavItem.targetState
          property var initHandler: dummyNavItem.initHandler // allows to set custom init handler function for each gnview page

          property alias contentArea: contentArea

          // connection to navigation, show target page if dummy is selected
          Connections {
            target: navigation || null
            onCurrentNavigationItemChanged: {
              if(navigation.currentNavigationItem === dummyNavItem) {
                dummyPage.navigationStack.popAllExceptFirst()
                initializePageForView(dummyPage)

                if(targetState === "leaderboard") {
                  // refresh it if we open the leaderboard from the Android nav drawer
                  gameNetworkViewItem.gnView.leaderboardView.refreshLeaderboards()
                } else if(targetState === "profile") {
                  // if opened from the main navigation, reset the binding to the currently logged in user
                  // TODO: maybe better to set this from another place!?
                  // if we have a custom gnView in place, reset the user here
                  if(gameNetworkViewItem.gnView.profileView["resetToLoggedInUser"]) {
                    gameNetworkViewItem.gnView.profileView.resetToLoggedInUser()
                  }
                }
              }
            }
          }

          // show target page if dummy becomes active on stack
          onIsCurrentStackPageChanged: {
            if(isCurrentStackPage) {
              initializePageForView(dummyPage)
            }
          }

          // switch active navigation items if users witches between leaderboard / profile in gnview
          // this is not needed any longer, because users cant switch to profile view any longer from within gameNetworkView
          /*
          Connections {
            target: navigation.currentNavigationItem === dummyNavItem && dummyNavItem.targetItem === gameNetworkViewItem && gameNetworkViewItem.gnView || null
            onStateChanged: {
              if(dummyPage.navigationStack.depth !== 1)
                return

              var targetItem = dummyNavItem.targetItem
              var state = targetItem.viewState
              if(Theme.isAndroid && state !== dummyNavItem.targetState) {
                if(state === "leaderboard") {
                  console.debug("switching to state leaderboard")
                  navigation.currentIndex = 7
                  // refresh it if we open the leaderboard from the gnView
                  gameNetworkViewItem.gnView.leaderboardView.refreshLeaderboards()
                } else if(state === "profile") {
                  navigation.currentIndex = 5
                  // if opened from the main navigation, reset the binding to the currently logged in user
                  // TODO: maybe better to set this from another place!?
                  // if we have a custom gnView in place, reset the user here
                  if(gameNetworkViewItem.gnView.profileView["resetToLoggedInUser"]) {
                    gameNetworkViewItem.gnView.profileView.resetToLoggedInUser()
                  }
                }
              }
            }
          }
          */

          Item {
            id: contentArea
            y: Theme.statusBarHeight
            width: parent.width
            height: parent.height - y

            property bool splitViewActive: dummyPage.navigationStack && dummyPage.navigationStack.splitViewActive
          }
        }
      }
    }
  } // dummy

  // dummy page component for wrapping gn/multiplayer views on iOS
  Component {
    id: dummyPageComponent

    Page {
      id: dummyPage
      navigationBarHidden: true
      title: "DummyPage"

      property Item targetItem
      property string targetState
      property var initHandler: function() { } // allows to set custom init handler function for each gnview page

      property alias contentArea: contentArea

      // show target page if dummy becomes active on stack
      onIsCurrentStackPageChanged: {
        if(isCurrentStackPage) {
          initializePageForView(dummyPage)
        }
      }

      NavigationBar {
        width: parent.width
      }

      Item {
        id: contentArea
        y: Theme.statusBarHeight
        width: parent.width
        height: parent.height - y

        property bool splitViewActive: dummyPage.navigationStack && dummyPage.navigationStack.splitViewActive
      }
    }
  }

  // initialize dummy page for gn or mp view display
  function initializePageForView(dummyPage) {
    dummyPage.targetItem.parent = hiddenItemContainer

    if(dummyPage.initHandler !== undefined)
      dummyPage.initHandler() // allows custom init code when pushing a page
    dummyPage.targetItem.viewState = dummyPage.targetState
    dummyPage.targetItem.parent = dummyPage.contentArea
    dummyPage.targetItem.navigationStack = dummyPage.navigationStack // allows pushing new gn pages
    dummyPage.targetItem.parentPage = dummyPage
    amplitude.logEvent("Open Social Page", {"page" : dummyPage.targetState})
  }

  Item {
    id: hiddenItemContainer
    visible: false
    anchors.fill: parent

    GameNetworkViewItem {
      id: gameNetworkViewItem
      state: "leaderboard"
      anchors.fill: parent
      onBackClicked: {
        if(Theme.isAndroid && navigation.currentNavigationItem.navigationStack.depth <= 1)
          navigation.drawer.open()
        else {
          gameNetworkViewItem.parent = hiddenItemContainer
          navigation.currentNavigationItem.navigationStack.pop()
        }
      }
    }

    // multiplayer view (only once per app)
    MultiplayerViewItem {
      id: multiplayerViewItem
      state: "inbox"
      anchors.fill: parent
      onBackClicked: {
        if(Theme.isAndroid && navigation.currentNavigationItem.navigationStack.depth <= 1)
          navigation.drawer.open()
        else {
          multiplayerViewItem.parent = hiddenItemContainer
          navigation.currentPage.navigationStack.pop()
        }
      }
    }
  }

  // addDummyNavItem - adds dummy nav item to app-drawer, which opens GameNetwork/Multiplayer page
  function addDummyNavItem(targetItem, targetState, title, icon, initHandler) {
    navigation.addNavigationItem(dummyNavItemComponent)
    var dummy = navigation.getNavigationItem(navigation.count - 1)
    dummy.targetItem = targetItem
    dummy.targetState = targetState
    if(initHandler)
      dummy.initHandler = initHandler
    dummy.title = title
    dummy.icon = icon
  }

  // buildPlatformNavigation - apply navigation changes for different platforms
  function buildPlatformNavigation() {
    var activeTitle = navigation.currentPage ? navigation.currentPage.title : ""
    var targetItem = navigation.currentPage && navigation.currentPage.targetItem || null
    var targetState = navigation.currentPage && navigation.currentPage.targetState ? navigation.currentPage.targetState : ""

    // hide multiplayer/gamenetwork views
    gameNetworkViewItem.parent = hiddenItemContainer
    multiplayerViewItem.parent = hiddenItemContainer

    // remove previous platform specific pages
    while(navigation.count > 4) {
      navigation.removeNavigationItem(navigation.count - 1)
    }

    // add new platform specific pages
    if(Theme.isAndroid) {
      // social
      addDummyNavItem(multiplayerViewItem, "friends", "Business Meet", IconType.group)
      addDummyNavItem(gameNetworkViewItem, "profile", "Your Profile", IconType.user, function() {
        // always show profile of logged in user when opened via menu item
        if(gameNetworkViewItem.gnView.profileView["resetToLoggedInUser"]) {
          gameNetworkViewItem.gnView.profileView.resetToLoggedInUser()
        }
      })
      addDummyNavItem(multiplayerViewItem, "inbox", "Chat", IconType.comment)
      addDummyNavItem(gameNetworkViewItem, "leaderboard", "Leaderboard", IconType.flagcheckered)

      // other
      navigation.addNavigationItem(tracksNavItemComponent)
      navigation.addNavigationItem(venueNavItemComponent)
      navigation.addNavigationItem(contactsNavItemComponent)
      navigation.addNavigationItem(settingsNavItemComponent)
      navigation.addNavigationItem(aboutVPlayNavItemComponent)

      if(activeTitle === "About V-Play")
        navigation.currentIndex = 12
      else if(activeTitle === "Settings")
        navigation.currentIndex = 11
      else if(activeTitle === "Contacts")
        navigation.currentIndex = 10
      else if(activeTitle === "Venue")
        navigation.currentIndex = 9
      else if(activeTitle === "Tracks")
        navigation.currentIndex = 8
      if(activeTitle === "DummyPage" || activeTitle === "More") { // "More" is used when splitView is active
        if(targetItem === gameNetworkViewItem && targetState === "leaderboard")
          navigation.currentIndex = 7
        else if (targetItem === multiplayerViewItem && targetState === "inbox")
          navigation.currentIndex = 6
        else if(targetItem === gameNetworkViewItem) // profile
          navigation.currentIndex = 5
        else if (targetItem === multiplayerViewItem) // business matchmaking
          navigation.currentIndex = 4
      }
    }
    else {
      navigation.addNavigationItem(moreNavItemComponent)

      if(!navigation.currentPage)
        return

      // open settings page when active
      if(activeTitle === "DummyPage") {
        navigation.currentIndex = navigation.count - 1 // open more page
        if(targetItem === gameNetworkViewItem && targetState === "leaderboard")
          navigation.currentPage.navigationStack.push(dummyPageComponent, { targetItem: gameNetworkViewItem, targetState: "leaderboard" })
        else if (targetItem === multiplayerViewItem && targetState === "inbox")
          navigation.currentPage.navigationStack.push(dummyPageComponent, { targetItem: multiplayerViewItem, targetState: "inbox" })
        else if(targetItem === gameNetworkViewItem) // profile
          navigation.currentPage.navigationStack.push(dummyPageComponent, { targetItem: gameNetworkViewItem, targetState: "profile" })
        else if (targetItem === multiplayerViewItem) // business matchmaking
          navigation.currentPage.navigationStack.push(dummyPageComponent, { targetItem: multiplayerViewItem, targetState: "friends" })
      }
      else if(activeTitle === "About V-Play") {
        navigation.currentIndex = navigation.count - 1 // open more page
        navigation.currentPage.navigationStack.push(Qt.resolvedUrl("pages/AboutVPlayPage.qml"))
      }
      else if(activeTitle === "Settings") {
        navigation.currentIndex = navigation.count - 1 // open more page
        navigation.currentPage.navigationStack.push(Qt.resolvedUrl("pages/SettingsPage.qml"))
      }
      else if(activeTitle === "Contacts") {
        navigation.currentIndex = navigation.count -1 // open more page
        navigation.currentPage.navigationStack.push(Qt.resolvedUrl("pages/ContactsPage.qml"))
      }
      else if(activeTitle === "Venue") {
        navigation.currentIndex = navigation.count - 1 // open more page
        navigation.currentPage.navigationStack.push(Qt.resolvedUrl("pages/VenuePage.qml"))
      }
      else if(activeTitle === "Tracks") {
        navigation.currentIndex = navigation.count - 1 // open more page
        navigation.currentPage.navigationStack.push(Qt.resolvedUrl("pages/TracksPage.qml"))
      }
    }
  }

  // openInbox activates inbox navigation item on Android or more navigation item with inbox page on iOS
  function openInbox() {
    if(Theme.isAndroid)
      navigation.currentIndex = 6 // go to inbox navigation item
    else {
      navigation.currentIndex = navigation.count - 1 // open more page
      var multiplayerPage = multiplayerViewItem.parentPage
      if(!multiplayerPage || !multiplayerPage.isCurrentStackPage || multiplayerViewItem.mpView.state !== "inbox")
        navigation.getNavigationItem(navigation.count - 1).navigationStack.push(dummyPageComponent, { targetItem: multiplayerViewItem, targetState: "inbox" }) // push inbox page
    }
  }

  // check app starts and show feedback dialog if required
  function checkFeedbackDialog() {
    if(DataModel.localAppStarts > 5 && !DataModel.feedBackSent) {
      likeDialog.open()
    }
  }

  FeedbackDialog {
    id: feedbackDialog
  }

  RatingDialog {
    id: ratingDialog
  }

  LikeDialog {
    id: likeDialog
    onCanceled: {
      amplitude.logEvent("Dislike App")

      // open the feedback dialog instead
      likeDialog.close()
      feedbackDialog.open()
    }
    onAccepted: {
      amplitude.logEvent("Like App")

      // open the rating dialog instead
      likeDialog.close()
      ratingDialog.open()
    }
  }
}

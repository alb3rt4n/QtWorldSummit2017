import VPlayApps 1.0
import QtQuick 2.0
import "../common"

ListPage {
  id: morePage
  title: "More"

  model: [
    { text: "Business Meet", section: "Social", state: "friends" },
    { text: "Your Profile", section: "Social",  state: "profile" },
    { text: "Chat", section: "Social",  state: "inbox" },
    { text: "Leaderboard", section: "Social", state: "leaderboard" },
    { text: "Tracks", section: "General", page: Qt.resolvedUrl("TracksPage.qml") },
    { text: "Venue", section: "General", page: Qt.resolvedUrl("VenuePage.qml") },
    { text: "QR Contacts", section: "General", page: Qt.resolvedUrl("ContactsPage.qml")},
    { text: "Settings", section: "General", page: Qt.resolvedUrl("SettingsPage.qml") },
    { text: "About V-Play", section: "General", page: Qt.resolvedUrl("AboutVPlayPage.qml") }
  ]

  section.property: "section"

  // TODO index is not ideal here, my speakers page already broke that shiat
  // open configured page when clicked
  onItemSelected: {
    if(index === 4 || index === 5 || index === 6 || index === 7 || index === 8)
      morePage.navigationStack.popAllExceptFirstAndPush(model[index].page)
    else {
      var properties = { targetState: model[index].state }
      if(index === 1 || index === 3) {
        properties["targetItem"] = gameNetworkViewItem

        if(index === 1) {
          // profile view
          // if opened from the main navigation, reset the binding to the currently logged in user
          // TODO: maybe better to set this from another place!?
          // if we have a custom gnView in place, reset the user here
          if(gameNetworkViewItem.gnView.profileView["resetToLoggedInUser"]) {
            gameNetworkViewItem.gnView.profileView.resetToLoggedInUser()
          }
        }
      }
      else if(index === 0 || index === 2) {
        properties["targetItem"] = multiplayerViewItem
      }
      morePage.navigationStack.popAllExceptFirstAndPush(dummyPageComponent, properties)
    }
  }
}

import QtQuick 2.0
import VPlay 2.0

Item {
  id: businessMeetView
  anchors.fill: parent

  // if this is set, as a workaround an "empty" search is a search with ":", which returns all users that have any customData field set. we could also search for "{" or """ for example, as this is also in the customData field
  // is set to true when called for the BusinessMeetView, but to false for the new chat view, which shows a list with first entries the latest signups to the app
  property bool filterToUsersWithCustomData: false

  property int shownAddFriendDialog: -1

//  property VPlayGameNetwork gameNetworkItem: socialViewItem.gameNetworkItem

  signal userSelected(var modelData)

  // is called if the multiplayerview state changed and when this view is shown
  signal shownAndStateChanged()

  // view property
  property color bodyColor: socialViewItem.bodyColor
  property color separatorColor: socialViewItem.separatorColor

  onShownAndStateChanged: {
    // refresh the current users
    userSelectorView.searchUsers()
  }

  // background
  Rectangle {
    anchors.fill: parent
    color: "white"
  }

  Connections {
    target: nativeUtils
    // this signal has the parameters accepted and enteredText
    onTextInputFinished: {
      // if the input was confirmed with Ok, store the userName as the property
      console.debug("OnTextInputFinished friends ", accepted, shownAddFriendDialog)
      if (shownAddFriendDialog > 0) {
        if (accepted) {
          gameNetworkItem.sendFriendRequest(shownAddFriendDialog, enteredText, function(success) {
            userSelectorView.searchUsers()
          })
        }
      }

      if(shownAddFriendDialog > 0) {
        shownAddFriendDialog = -1
      }
    }
  }

  // this view has a users property, this users property makes a copy of the current users
  UserSelectorView {
    id:userSelectorView

    anchors.fill: parent

    filterToUsersWithCustomData: businessMeetView.filterToUsersWithCustomData
    userItemDelegate: BusinessMeetActionCell {
      width: businessMeetView.width

      onClicked: userSelected(modelData)

      onActionClicked: {
        if(action.text===qsTr("Accept")) {
          actionButton.enabled = false
          gameNetworkItem.sendFriendResponse(modelData.value, function(success) {
            actionButton.visible = false
            userSelectorView.searchUsers()
          })
        }
      }
    }

    onUsersChanged: {
      // console.log("OnUsersChanged " + JSON.stringify(users))

      if(typeof users === 'undefined') {
        return;
      }

      // sort users by friendship status
      // also see FriendsSelectorView
      gameNetworkItem.sortUserListByStatusAndName(users)

      var cells = [];
      for (var i=0; i<users.length; i++) {
        var friend = users[i];
        cells.push(getUser(friend));
      }
      userItemModel=cells
    }

    function isMe(modelData) {
      return modelData.id === gameNetworkItem.user.userId
    }

    function getUser(friend){
      var name = gameNetworkItem.getDisplayNameFromUserName(friend.name)
      var user = {
        text: name,
        value: friend.id,
        profile_picture: friend.profile_picture,
        locale: friend.locale,
        customData: friend.data, // custom user data
        friendStatus: friend.status || ""
      }

      if(friend.status === "requested") {
        user['subText'] = qsTr("You sent a friend request")
      }
      else if(friend.status === "confirmed") {
        user['subText'] = qsTr("You are friends")
      }      
      else if(friend.status === "pending") {
        user['subText'] = qsTr("Waiting for friend approval")
      }
      else if(isMe(friend)) {
        // as we add a subText here, the own user cannot be clicked any more and thus prevents sending a friend request to self
        user['subText'] = qsTr("This is you")
      }

      return user
    }

    function showPlayerNameChangeDialog(id,title, description, placeholder) {
      shownAddFriendDialog = id
      var desc = description ? description : ""
      var placeholderText = placeholder ? placeholder : ""
      nativeUtils.displayTextInput(title, desc, placeholderText, "")
    }
  }
}

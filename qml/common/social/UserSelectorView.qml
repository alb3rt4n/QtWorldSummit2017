import VPlay 2.0
import VPlayApps 1.0
import QtQuick 2.0
import QtQuick.Controls.Styles 1.4
import QtQuick.Controls 1.4

Item {
  property bool singleSelection: false

  property bool filterToUsersWithCustomData: false

  // we must not connect here directly - it shall only be updated if this view is active; also, we need to make a copy here for sorting
  property variant users//: gameNetworkItem.userSearchResult
  property variant selected
  property variant gameNetworkItem: socialViewItem.gameNetworkItem
  property variant multiplayerItem: socialViewItem.multiplayerItem
  property variant pageMetaData
  property alias userItemDelegate: userListView.delegate
  property alias userHeaderDelegate: userListHeader.sourceComponent
  property alias userItemModel:userListView.model

  signal cellSelected(var cell)

  // if this is set to true, automatically call search when visible changes to true
  property bool autoLoadWhenVisible: false

  Connections {
    // only listen to the changes if visible
    target: gameNetworkItem && visible ? gameNetworkItem : null

    onUserSearchResultChanged: {
      if(!gameNetworkItem.userSearchResult) {
        users = undefined
      } else {
        // we need to make a copy here, otherwise it would have side-effects that the original raw search data is used
        users = JSON.parse(JSON.stringify(gameNetworkItem.userSearchResult))
      }

    }
  }

  Loader {
    id: userListHeader
    sourceComponent: Item {}
  }

  Row {
    id: searchRow
    anchors.top: userListHeader.bottom
    height: dp(Theme.navigationBar.height)
    width: parent.width

    Rectangle {
      width: parent.width - sendWrapper.width
      height: parent.height
      color: "#f8f8f8"

      Rectangle {
        anchors.centerIn: parent
        width: query.width + dp(16) + cancelButton.width
        height: sendButton.height// + dp(6)
        color: "#fff"
        border.color: Theme.navigationBar.dividerColor
        border.width: px(1)
        radius: sendButton.radius
      }

      TextInput {
        id: query
        anchors.verticalCenter: parent.verticalCenter
        x: dp(24)
        width: parent.width - 2 * x - cancelButton.width
        height: parent.height
        font.pixelSize: sp(16)
        verticalAlignment: Text.AlignVCenter
        color: bodyColor
        clip: true

        onAccepted: {
          query.focus = false
          searchUsers()
        }
      }

      ActionButton {
        id: cancelButton
        anchors.left: query.right
        anchors.verticalCenter: parent.verticalCenter
        visible: query.focus || query.displayText != ""
        color: "#ddd"
        textColor: "#bbb"
        radius: width/2
        text: IconType.remove//qsTr("Send")
        font.family: Theme.iconFont.name
        textSize: sp(10)
        paddingHorizontal: dp(8)
        paddingVertical: dp(8)

        onClicked:{
          query.focus = false
          query.text = ""
          searchUsers()
        }
      }
    }

    Rectangle {
      id: sendWrapper
      width: sendButton.width + dp(16)
      height: parent.height
      color: "#f8f8f8"

      ActionButton{
        id: sendButton
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        color: socialViewItem.tintColor
        text: IconType.search//qsTr("Send")
        font.family: Theme.iconFont.name
        paddingHorizontal: dp(8)
        paddingVertical: dp(8)
        radius: width/2

        onClicked: {
          query.focus = false
          searchUsers()
        }
      }
    }
  }

  Rectangle {
    width: parent.width
    height: px(1)
    anchors.bottom : searchRow.bottom
    color: Theme.navigationBar.dividerColor//separatorColor
  }

  Column{
    id: cellList

    spacing: 1
    //anchors.topMargin: dp(16)
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: searchRow.bottom
    anchors.bottom: parent.bottom

    property bool selectable: !singleSelection

    AppListView {
      id: userListView

      width: parent.width
      height: parent.height
      footer: FriendsLoadMoreDelegate {
        visible: (pageMetaData && pageMetaData["showLoadMoreButton"]) ? pageMetaData["showLoadMoreButton"] : false

        onLoadMoreClicked: {
          gameNetwork.loadMore
              ({
                 action: "search_user",
                 query: query.text
               })
        }
      }
    }
  }

  onVisibleChanged: {
    // this is a workaround to avoid loading when navigating towards another scren, or when coming back to the screen
    // instead, a new searchUsers() is called when navigating to the view
    // does not work if opened from new chat!
    // do not refresh data if page is not active one (e.g. visiblity changes during navstack transition to profile view)
    //if(navigationStack && navigationStack.currentPage !== multiplayerViewItem.parentPage) {
    //  console.debug("UserSelectorView: currently transitioning between pages, do not call searchUsers server request")
    //  return
    //}

    if(visible && autoLoadWhenVisible){
      searchUsers()
    }
  }

  onUsersChanged: {
    if (gameNetworkItem !== undefined && gameNetworkItem.pageForRequestMetaData !== undefined) {
      pageMetaData = gameNetworkItem.pageForRequestMetaData["search_user"]
    }
  }

  function searchUsers() {
    console.debug("query.text:", query.text)
    var queryText = query.text
    if(queryText.length === 0 && filterToUsersWithCustomData) {
      // this is a workaround, as a user who has entered any customData field hast this char in the customData string! we could also use "{" or """ for example
      queryText = ":"
    }

    //gameNetworkItem.searchUser(query.text); // searches only for the name, not for customData
    // For searching in customData we need to provide a stringified JSON query in this format (2 stringifies required!)
    // As empty parameters are not allowed, we match by a " " (whitespace) if no query is provided
    var filterQuery = queryText.length > 0 ? JSON.stringify(JSON.stringify({"filter": queryText})) : " "
    gameNetworkItem.searchUser(filterQuery)
    if(query.text != "") {
      amplitude.logEvent("Search User",{"term" : query.text})
    }
  }

  function getPlayers(){
    var players =[{name: qsTr("Me"), type: "me"}];

    for (var i = 0; i <  cellList.cells.length; i++) {
      var cell =  cellList.cells[i]
      var cellObject =  cellList.cellViews[i]
      console.log("Cell " +JSON.stringify(cell));

      if(cellObject.selected){
        if(players.length <= multiplayer.playerCount){

          players.push({name: cell.text, type:'userId',value:cell.value})
        }
      }
    }

    console.log("Players " +JSON.stringify(players) +" " + players)
    while(players.length <= matchmakingScene.playerCount){
      players.push({name: "?", type:'auto',value:-1})
    }

    return players
  }

  function getSelected(){
    var selected =[];

    for (var i = 0; i <  cellList.cells.length; i++) {
      var cell =  cellList.cells[i]
      var cellObject =  cellList.cells[i]

      if(cellObject.selected){
        if(selected.length <= multiplayerItem.playerCount){

          selected.push({name: cell.text, userId: cell.value})
        }
      }
    }

    console.log("Players " +JSON.stringify(selected) +" " + selected)
    return selected
  }
}

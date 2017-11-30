import VPlay 2.0
import QtQuick 2.0

Item {
  height: loadMoreButton.height + dp(16)

  signal loadMoreClicked

  ActionButton {
    id: loadMoreButton

    textColor: bodyColor
    text: qsTr("Show more...")
    anchors.centerIn: parent

    onClicked: {
      loadMoreClicked()
    }
  }
}

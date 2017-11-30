import QtQuick 2.0

Rectangle {
  id: button

  color: "transparent"
  width: buttonText.width + paddingHorizontal * 2
  height: buttonText.height + paddingVertical * 2
  radius: 3

  property int paddingHorizontal: dp(16)
  property int paddingVertical: dp(8)

  // button properties
  property alias text: buttonText.text
  property alias textColor: buttonText.color
  property alias textSize: buttonText.font.pixelSize
  property alias backgroundColor: button.color
  property alias font: buttonText.font

  // called when the button is clicked
  signal clicked

  Text {
    id: buttonText
    font.pixelSize: sp(22) // in ActionCell, the size is set to sp(15)
    color: "white"
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenter: parent.horizontalCenter
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    onClicked: button.clicked()
    onPressed: button.opacity = 0.6
    onReleased: button.opacity = 1
    preventStealing: true
  }
}

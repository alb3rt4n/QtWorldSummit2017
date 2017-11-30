import QtQuick 2.5
import QtGraphicalEffects 1.0
import VPlay 2.0 // needed for MultiResolutionImage

/*!
  \internal

  A rounded image view adapting facebook profile image urls to scale with our contentscalefactor
 */
Item {
  id: roundedImage

  // Source for the masked profile picture
  property url source

  // Defines if the "edit" picture overlay should be shown
  property bool editable: false
  // Defines the background color of the edit overlay
  property color editBackgroundColor: "#bbbbbb"

  property string placeholderImage: "\uf007" // the default user icon
  property color placeholderBackgroundColor: "#eee"


  // custom radius, by default image width / 2
  property alias radius: maskObject.radius

  // Emitted when the edit button was clicked
  signal editClicked

  // Can be removed as soon as there is SSL support on iOS
  onSourceChanged: {

    var modifiedSource

    // Modify a Facebook URL to change https to http, as SSL is not supported in iOS as of now
    // Sample URL: https://fbcdn-profile-a.akamaihd.net/static-ak/...
    if (source.toString().indexOf("https://fbcdn") === 0)
      modifiedSource = source.toString().replace("https://fbcdn", "http://fbcdn")
    else
      modifiedSource = source.toString()

    // this is either 1 (sd), 2 (hd) or 4 (hd2)
    var contentScaleFactor = 1 / internalContentScaleFactorForImages


    // if the profile image is from fb, use a higher-res image based on the contentScaleFactor
    // example original url: https://fbcdn-profile-a.akamaihd.net/hprofile-ak-xpa1/t1.0-1/c7.0.50.50/p50x50/45248_1166665903157_8039875_n.jpg
    // modified url: http://fbcdn-profile-a.akamaihd.net/hprofile-ak-xpa1/t1.0-1/c7.0.200.200/p200x200/45248_1166665903157_8039875_n.jpg
    // new example original url: http://graph.facebook.com/100007746184654/picture?width=50&height=50&return_ssl_resources=0
    if(contentScaleFactor > 1 &&
        (modifiedSource.toString().indexOf("http://fbcdn") === 0 || modifiedSource.toString().indexOf("http://graph.facebook.com") === 0)) {

      if(contentScaleFactor >= 4) {
        // the default image size is 50x50 px, as we display it with logical 50px, it must be *4 for hd2 screens thus 200px
        modifiedSource = modifiedSource.replace("p50x50", "p200x200")
        // sometimes the received image part is also given as /c7.0.50.50/ - in that case also replace it with 200x200 px
        modifiedSource = modifiedSource.replace("50.50", "200.200")
        // new facebook pictures also have a dynamic url
        modifiedSource = modifiedSource.replace("width=50&height=50", "width=200&height=200")
      } else if(contentScaleFactor >= 2) {
        modifiedSource = modifiedSource.replace("p50x50", "p100x100")
        modifiedSource = modifiedSource.replace("50.50", "100.100")
        modifiedSource = modifiedSource.replace("width=50&height=50", "width=100&height=100")
      }
    }

    // Check if we have an image from our vpgn hosting, reqeust a lower resolution in that case
    if (modifiedSource.indexOf("/pictures/") > 0) {
      if(contentScaleFactor >= 4) {
        modifiedSource = modifiedSource + "/400x400"
      }
      else if (contentScaleFactor >= 2) {
        modifiedSource = modifiedSource + "/200x200"
      }
      else {
        modifiedSource = modifiedSource + "/100x100"
      }
    }

    // console.debug("fb profile image modifedSource:", modifiedSource)
    avatar.source = modifiedSource
  }

  // old: we can use an Image here, it gets applied the contentScale but as the source image size is big enough it looks not blurry
  // we cannot use a normal image, because then the OpacityMask would make it look blurry (as only the logical size is used not the real size)

  // scaling is required otherwise the image would be blurred due to content scaling
  Item {
    scale: internalContentScaleFactorForImages
    transformOrigin: Item.TopLeft
    // we need to set a height so verticalCenter anchor works
    height: avatar.height * internalContentScaleFactorForImages
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // border
    Rectangle {
      // make it as big as the UserImage, the contentScale factor is applied internally, if the image source is big enough (50*4 on hd2 for example), it is not blury
      width: roundedImage.width / internalContentScaleFactorForImages
      height: roundedImage.height / internalContentScaleFactorForImages

      color: placeholderBackgroundColor

      // Placeholder icon
      Text {
        // icontFontName may not be known if the UserImage is not used within GameNetworkView; to avoid errors in the log, add this if-check
        font.family: socialViewItem.iconFontName
        visible: placeholderImage.length > 0 && (avatar.source === undefined || avatar.source.toString().length === 0)
        text: placeholderImage
        font.pixelSize: parent.width * 0.75
        color: "#bbb"
        anchors.centerIn: parent
      }

      // actual image
      Image {
        id: avatar
        //anchors.verticalCenter: parent.verticalCenter - is done above
        anchors.fill: parent

        // setting the sourceSize is not a good idea, because this would only take the logical size and not multipl with the contentScale
        //sourceSize: Qt.size(parent.width, parent.height)

        // the img looks blurry with this setting (probabl because it uses the local size and not multiplied the contentScale factor), thus disable it
        // we need to add it however, otherwise images from users are completely stretched when not square format (like from facebook before)
        fillMode: Image.PreserveAspectCrop
        autoTransform: true

        smooth: true
      }

      // edit mask
      Rectangle {
        visible: roundedImage.editable
        width: parent.width
        height: parent.height * 0.35
        anchors.bottom: parent.bottom
        color: roundedImage.editBackgroundColor
        opacity: clickArea.pressed ? 0.4 : 0.55

        Text {
          anchors.centerIn: parent
          text: qsTr("Edit")
          font.pixelSize: parent.height * 0.5
          color: "white"
        }
      }

      Rectangle {
        id: maskObject
        // the black part is the inner circle
        color: "black"
        anchors.fill: avatar
        radius: avatar.width * 0.5
        visible: false
        smooth: true
      }

      // add rounded image effect
      layer.effect: OpacityMask { maskSource: maskObject }
      layer.enabled: true

      // Click area for edit button
      MouseArea {
        id: clickArea
        anchors.fill: parent
        enabled: roundedImage.editable

        onClicked: roundedImage.editClicked()
      }
    }


  }// end of scaled Item

  /*
    This is the required input property to set the FlagImage
   */
  property alias locale: flagImage.locale

  /*
    like this you could set custom anchors, e.g. to the right:
    flagImageAnchors.right: userImage.right
    flagImageAnchors.left: null
   */
  property alias flagImageAnchors: flagImage.anchors
  // by default, it is visible if locale is set
  property alias displayFlagImage: flagImage.visible
  // can be set manually if no gameNetworkItem or gameNetwork id exists, e.g. in games where the flag wants to be used like in PlayerTag.qml of ONU
  property alias flagImageSource: flagImage.source

  SocialFlagImage {
    id: flagImage

    height: parent.height * 0.22
    anchors.bottom: parent ? parent.bottom : undefined
    // the margin also should be relative to the size
    anchors.bottomMargin: parent ? -parent.height*0.08 : 0
    anchors.left: parent ? parent.left : undefined
    anchors.leftMargin: parent ? -parent.width*0.08 : 0
  }
}

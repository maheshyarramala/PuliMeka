# Puli Meka

A mobile board-game app made with Flutter. It has two traditional games:

## Puli Meka (Tigers and Goats)
- 3 tigers against 15 goats on a 23-point board.
- Goats place their pieces first, then move. Tigers move or jump over goats to capture them.
- Tigers win by capturing 15 goats. Goats win by trapping all the tigers.

## Three Pawns (Tapatan / Three Men's Morris)
- 3 pawns each on a 3x3 board with diagonals.
- Take turns placing the pawns, then slide them one step along the lines.
- Three in a straight line wins. A blocked player loses. The same position three times is a draw.

## Features
- Play against the computer (Easy, Medium or Hard) or with a friend on the same phone.
- Animated pieces, sound effects, vibration and a mute button.
- Works on phones and tablets, in portrait and landscape.
- How to play screen for each game.

## Run it
```
flutter pub get
flutter run
```

Sound effects are in `assets/sounds/`. The app icon is in `assets/icon/`.

## Build and publish a versioned APK

The GitHub Actions workflow builds a version-named APK on pushes and pull
requests. To publish an APK on the repository's **Releases** page:

1. Update `version` in `pubspec.yaml` (for example, `1.0.1+2`).
2. Commit and push that change to `main`.
3. Create and push a tag matching the version name (for example, `v1.0.1`):

   ```
   git tag v1.0.1
   git push origin v1.0.1
   ```

The workflow builds the APK and attaches it to the matching GitHub Release as
`puli-meka-1.0.1+2.apk`. The build number after `+` is included in the APK
filename but not in the release tag.

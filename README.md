# Mosaic

Collaborative multiplayer Game where players rearrange fragments to form images.

Made in 72 hours for the ["STOP WAITING FOR GODOT" Game Jam](https://itch.io/jam/stop-waiting-for-godot).
You can play the [web version on itch](https://winston-yallow.itch.io/mosaic).

## Details

This uses WebRTC to create a peer to peer network. A small signalling server is needed
so that the peers can discover each other and exchange SDP offers as well as ICE candidates.
The [Mosaic Server](https://github.com/winston-yallow/mosaic-server) I wrote uses python,
but the protocol is quite simple and it should be easy to recreate it or adjust it to your needs.

I made this game in a quite limited timeframe so please expect bugs. I also did not follow best
practices wherever that would save some time in the sort term. For a long term project that is
probably not the best approach.

Most code files have at least a small description on the top. If you have questions don't hesitate
to ask, I did not add many comments to the code.

## Licenses

My code: MIT License

Godot Engine: MIT License

Music Jingles by Kenney: Creative Commons Zero (CC0)

Poppins Font: Open Font License (OFL)

## Resources

- [Twitter thread](https://twitter.com/WinstonYallow/status/1435180419717210112) by me describing some of the mesh networking from this game
- [Godot Game Engine](https://godotengine.org/)
- [Music Jingles by Kenney](https://www.kenney.nl/assets/music-jingles)
- [Poppins Font on fonts.google.com](https://fonts.google.com/specimen/Poppins)


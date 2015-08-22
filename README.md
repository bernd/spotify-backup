# spotify-backup

Backup a list of your [Spotify](http://www.spotify.com/) saved tracks,
artists and playlists.

## Requirements

Ruby >= 2.0 (no extra gems needed)

## Usage

You have to [create an OAuth token](https://developer.spotify.com/web-api/console/get-current-user-saved-tracks/)
to be able to access your data.

Create the token with the scopes shown in the screenshot.

![Spotify OAuth Token Creation](/images/create-token.png)

The generated token needs to be exported into the `SPOTIFY_TOKEN` environment
variable before running the script.

Example:

```
$ export SPOTIFY_TOKEN=<spotify oauth token>
$ ruby spotify-backup.rb /output/path
Writing /output/path/spotify-20150822-190843-tracks.json
Writing /output/path/spotify-20150822-190843-artists.json
Writing /output/path/spotify-20150822-190843-playlists.json
```

The script creates a separate JSON files for tracks, artists and playlists
in the output path.

**WARNING:** The token times out pretty quick so it cannot really be used in
automatic backup scripts.

## Contributing

All contributions are welcome!

## License

[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) - See [LICENSE](/LICENSE) file for details.

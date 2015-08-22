#!/usr/bin/env ruby

# Copyright 2015 Bernd Ahlers
#
# The Netty Project licenses this file to you under the Apache License,
# version 2.0 (the "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at:
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

require 'net/http'
require 'json'
require 'time'
require 'fileutils'

class SpotifyHTTP
  def initialize(base_url, token)
    @uri = URI.parse(base_url)
    @token = token

    @http = Net::HTTP.new(@uri.host, @uri.port)
    @http.use_ssl = @uri.scheme == 'https'
    @cache = {}
  end

  def me
    @cache['me'] ||= get('me')
  end

  def my_id
    me[:id]
  end

  def my_tracks
    get_all("me/tracks?limit=50").map do |track|
      track = track[:track]
      {
        name: track[:name],
        uri: track[:uri],
        album: {
          name: track[:album][:name],
          uri: track[:album][:uri],
        },
        artists: track[:artists].map {|artist|
          {
            name: artist[:name],
            uri: artist[:uri],
          }
        }
      }
    end
  end


  def my_artists
    get_all("me/following?type=artist&limit=50", :artists).map do |artist|
      {
        name: artist[:name],
        uri: artist[:uri],
        followers: artist[:followers][:total]
      }
    end.sort {|a, b| a[:name] <=> b[:name] }
  end

  def my_playlists
    get_all("users/#{my_id}/playlists?limit=50").map do |playlist|
      {
        name: playlist[:name],
        uri: playlist[:uri],
        public: playlist[:public],
        tracks: Array(my_playlist_tracks(playlist[:id])).map {|track|
          track = track[:track]
          {
            name: track[:name],
            uri: track[:uri],
            album: {
              name: track[:album][:name],
              uri: track[:album][:uri]
            },
            artists: Array(track[:artists]).map {|artist|
              {
                name: artist[:name],
                uri: artist[:uri]
              }
            }
          }
        }
      }
    end.sort {|a, b| a[:name] <=> b[:name] }
  end

  def my_playlist_tracks(playlist_id)
    get_all("users/#{my_id}/playlists/#{playlist_id}/tracks?limit=100")
  end

  private

  def get_all(path, key = nil)
    data = key.nil? ? get(path) : get(path).fetch(key, {})
    items = data.fetch(:items, [])

    while data[:next]
      data = key.nil? ? get(data[:next]) : get(data[:next]).fetch(key, {})
      items.concat(data.fetch(:items, []))
    end

    items
  end

  def get(path, default = {})
    if @cache.has_key?(path)
      return @cache.fetch(path)
    end

    $stderr.puts "==> Getting #{@uri.merge(path)}"
    req = Net::HTTP::Get.new(@uri.merge(path))

    req['Authorization'] = "Bearer #{@token}"
    req['Accept'] = 'application/json; charset=utf-8'

    res = @http.start { @http.request(req) }

    case res
    when Net::HTTPSuccess
      @cache[path] = JSON.parse(res.body, symbolize_names: true)
    else
      $stderr.puts "ERROR: #{res.code} - #{res.message}: #{res}"
      default
    end
  end
end

output = ARGV.shift

unless output
  $stderr.puts("Usage: #{File.basename($0)} /output/path")
  exit 1
end

unless File.exist?(output)
  $stder.puts("Creating output directory: #{output}")
  FileUtils.mkdir_p(output)
end

spotify = SpotifyHTTP.new('https://api.spotify.com/v1/', ENV['SPOTIFY_TOKEN'])
timestamp = Time.now.strftime('%Y%m%d-%H%M%S')

tracks_file = File.join(output, "spotify-#{timestamp}-tracks.json")
artists_file = File.join(output, "spotify-#{timestamp}-artists.json")
playlists_file = File.join(output, "spotify-#{timestamp}-playlists.json")

$stderr.puts("Writing #{tracks_file}")
File.open(tracks_file, 'w') do |f|
  f.puts(JSON.dump(spotify.my_tracks))
end

$stderr.puts("Writing #{artists_file}")
File.open(artists_file, 'w') do |f|
  f.puts(JSON.dump(spotify.my_artists))
end

$stderr.puts("Writing #{playlists_file}")
File.open(playlists_file, 'w') do |f|
  f.puts(JSON.dump(spotify.my_playlists))
end

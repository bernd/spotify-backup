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

  def tracks
    get_all('me/tracks?limit=50').map do |track|
      track = track[:track]
      {
        name: track[:name],
        uri: track[:uri],
        album: {
          name: track[:album][:name],
          uri: track[:album][:uri]
        },
        artists: track[:artists].map do |artist|
          {
            name: artist[:name],
            uri: artist[:uri]
          }
        end
      }
    end
  end

  def artists
    get_all('me/following?type=artist&limit=50', :artists).map do |artist|
      {
        name: artist[:name],
        uri: artist[:uri],
        followers: artist[:followers][:total]
      }
    end.sort { |a, b| a[:name] <=> b[:name] }
  end

  def playlists
    get_all("users/#{my_id}/playlists?limit=50").map do |playlist|
      {
        name: playlist[:name],
        uri: playlist[:uri],
        public: playlist[:public],
        tracks: Array(playlist_tracks(playlist[:id])).map do |track|
          track = track[:track]
          {
            name: track[:name],
            uri: track[:uri],
            album: {
              name: track[:album][:name],
              uri: track[:album][:uri]
            },
            artists: Array(track[:artists]).map do |artist|
              {
                name: artist[:name],
                uri: artist[:uri]
              }
            end
          }
        end
      }
    end.sort { |a, b| a[:name] <=> b[:name] }
  end

  def playlist_tracks(playlist_id)
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
    return @cache.fetch(path) if @cache.key?(path)

    $stdout.puts "==> Getting #{@uri.merge(path)}"
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

output_directory = ARGV.shift

unless output_directory
  $stderr.puts("Usage: #{File.basename($PROGRAM_NAME)} /output/path")
  exit 1
end

if ENV['SPOTIFY_TOKEN'].nil? || ENV['SPOTIFY_TOKEN'].empty?
  $stderr.puts('You have to set SPOTIFY_TOKEN environment variable.')
  exit 1
end

unless File.exist?(output_directory)
  $stdout.puts("Creating output directory: #{output_directory}")
  FileUtils.mkdir_p(output_directory)
end

spotify = SpotifyHTTP.new('https://api.spotify.com/v1/', ENV['SPOTIFY_TOKEN'])
timestamp = Time.now.strftime('%Y%m%d-%H%M%S')

%w(tracks artists playlists).each do |backup_type|
  filename = "spotify-#{timestamp}-#{backup_type}.json"
  $stdout.puts("Writing #{filename}")

  File.open(File.join(output_directory, filename), 'w') do |f|
    f.puts(JSON.dump(spotify.send backup_type))
  end
end

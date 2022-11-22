require 'yaml/store'
require 'gosu'
require 'rubygems'
class ArtWork
	attr_accessor :bmp

	def initialize (file)
		if (file != nil) # nil when no artwork
			@bmp = Gosu::Image.new(file.chomp)
		else
			@bmp = nil
		end
	end
end

class Tracks
	attr_accessor :title, :location
	def initialize (title, location)
		@title = title
		@location = location.to_s.chomp
	end
end

class Albums
	attr_accessor :title, :artist, :artwork, :tracks
	def initialize (title, artist, art_loc, tracks)
		@title = title
		@artist = artist
		@artwork = ArtWork.new(art_loc)
		@tracks = tracks
	end
end
module Persist_store
	extend self
	def read_store(id)
        store = YAML::Store.new('album_type.yaml')
        playlists = store.transaction {store['playlist']}
        case id
		when 'playlists'
			get_playlists(playlists)
		when 'write_to_existing_playlist'
		end
	end

	def get_playlists(store)
		titles = store.keys
		playlists = Array.new()
		tracks = Array.new()
		all_tracks = get_tracks(store)

		playlist_no = 0
		while (playlist_no < titles.length) # iterate for each playlist
			playlists << Albums.new(titles[playlist_no], nil, nil, all_tracks[playlist_no])
			playlist_no += 1
		end
		return playlists
	end

    def get_tracks(store)
        playlist_key = store.keys # name of playlist
        track_title = Array.new() # {playlist1}, {playlist2}
        track_location = Array.new() # {playlist1}, {playlist2}
        tracks = Array.new() # {instance tracks}, {instance tracks}

		index = 0
		while (index < playlist_key.length) # interate for get playlist data
			key = playlist_key[index]
			track_title[index] = store[key].keys
			track_location << store[key].values
			playlist_tracks = Array.new()
			
			track_no = 0
			while (track_no < track_title[index].length)
				playlist_tracks << Tracks.new(track_title[index][track_no], track_location[index][track_no])
				track_no += 1
			end

			tracks << playlist_tracks
			index += 1
		end
        return tracks
    end

    def write_store(store, key, array)
        array.each {|val|
			store[key] << val
		}
		store.commit
    end
end

# class Main < Gosu::Window

# 	def initialize
# 		super 300, 300
# 		playlist = Playlist_store::read_store('playlists')
# 		puts(playlist[0].tracks[0].title)
# 	end


# 	def display_btn_albums(albums)
# 		index = 0
# 		while (index < albums.length)
# 			@button_font.draw_text("#{albums[index].title}", 5, 105 + index*20, ZOrder::UI, 0.15, 0.15, BLACK, mode=:default)
# 			index += 1
# 		end
# 	end
# 	def display_btn_playlist(playlist)
# 		index = 0
# 		while (index < playlist.length)
# 			@button_font.draw_text(@playlist[index], 5, 105 + index*20, ZOrder::UI, 0.15, 0.15, BLACK, mode=:default)
# 			index += 1
# 		end
# 	end
# end

# Main.new.show if __FILE__ == $0

def main
	playlist = 
end
main()

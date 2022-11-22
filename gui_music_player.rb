require 'rubygems'
require 'gosu'
require 'yaml/store'

TOP_COLOR = Gosu::Color.new(0xFF1EB1FA)
BOTTOM_COLOR = Gosu::Color.new(0xFF1D4DB5)

BLACK = Gosu::Color.argb(0xff_000000)
GRAY = Gosu::Color.argb(0xff_808080)
WHITE = Gosu::Color.argb(0xff_ffffff)
BLUE = Gosu::Color.argb(0xff_0000ff)
GREEN = Gosu::Color::GREEN

SCREEN_HEIGHT = 800
SCREEN_WIDTH = 600

GENRE_NAMES = ['Null', 'Pop', 'Classic', 'Jazz', 'Rock']

module Genre
	POP, CLASSIC, JAZZ, ROCK = *1..4
end

# only use INTERACT for responsiveness
# e.g. when mouse hover button highlight
# to identify it as a button to user
module ZOrder
  BACKGROUND, PLAYER, UI, INTERACT = *0..3
end

# change mode window. MENU window.
# display all ALBUM window or
# display all PLAYLIST window
module Button_type
	NONE, ALBUM, PLAYLIST = *1..3
end

# type select
module Button_select
	NONE, ALBUM, TRACK, PLAYLIST, ADD_TRACK = *1..5
end

module Buttons
	extend self
	def btn_check_panel(id, btn_numbers)
		case id
		when 'left'
			btn_check_pressed(0, 200, btn_numbers)
		when 'right'
			btn_check_pressed(205, 600, btn_numbers)
		end
	end

	def btn_check_pressed(rightX, leftX, btn_numbers)
		buttons = Array.new()
		for x in 0..(btn_numbers - 1)
			topY = 105 + x*20
			bottomY = 120 + x*20
			buttons << {
				:rightX => rightX, 
				:leftX => leftX, 
				:topY => topY, 
				:bottomY => bottomY
			}
		end
		return buttons
	end
end

# Module consisting methods to read and create
# album/track instances using class Album and Tracks
# from text file; returns array of these instances
# selected file determined in main GUI window initialization
module Album_file
	extend self
	def read_track(music_file)
		title = music_file.gets
		track_loc = music_file.gets
		return Tracks.new(title, track_loc)
	end
	
	def read_tracks(music_file)
		num_tracks = music_file.gets.to_i
		tracks = Array.new()
		track_no = 0
		while (track_no < num_tracks)
			track = read_track(music_file)
			tracks << track
			track_no += 1
		end
		music_file.gets # empty space
		return tracks
	end

	def read_album(music_file)
		title = music_file.gets
		artist = music_file.gets
		art_loc = music_file.gets
		tracks = read_tracks(music_file)
		return Albums.new(title, artist, art_loc, tracks)
	end

	def read_albums(music_file)
		num_albums = music_file.gets.to_i
		albums = Array.new()
		album_no = 0
		while (album_no < num_albums)
			album = read_album(music_file)
			albums << album
			album_no += 1
		end
		return albums		
	end
end

# Persistent storage to seperate main album list file
# from stored key pair values for use in music player
# Example: playlist feature => {album1, album2, album3}
# file format: yaml
# refresh file by creating new file
module Persist_store
	extend self
	def read_store(id)
        store = YAML::Store.new('album_type.yaml')
        playlists = store.transaction {store['playlist']}
        case id
		when 'playlists'
			get_playlists(playlists)
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

    def write_store(key, val)
		store = YAML::Store.new('album_type.yaml')
		store.transaction do
		store['playlist'][key] = val
		store.commit
		end
    end
end

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
		@location = location.chomp
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

class MusicPlayerMain < Gosu::Window

	def initialize
	    super SCREEN_WIDTH, SCREEN_HEIGHT
	    self.caption = "Music Player"
		@button_font = Gosu::Font.new(100)
		@info_font = Gosu::Font.new(100)

		# read files and get instance of folder/track
		@music_file = File.new('albums.txt')
		@albums = Album_file::read_albums(@music_file)
		@playlists = Persist_store::read_store('playlists') # gets all playlist name
		# selected folder
		@tracks = nil
		@folder_titles = Array.new()
		@track_titles = Array.new()
		@track_display = false
		# selected track
		@add_options = Array.new()
		@add_tracks = Array.new()
		@current_folder = nil
		@current_song = nil
		@song = nil
		# id selection for pick
		@folder_id = nil 
		@track_id = nil
		# button events
		@btn_selected = false # if a btn is pressed
		@int_btn = 2 # fixed start for menu unless add new feature
		@btn_folder = 0
		@btn_tracks = 0
		@int_btn_tracks = 0
		# variable modes; set NONE in Menu Window
		@window_mode = Button_type::NONE
		@select_mode = Button_select::NONE

		@time_delay = 0 # reset every 50 seconds in update
	end

  	# Takes a track index and an Album and plays the Track from the Album
  	def playTrack
		begin			
			@current_song = @tracks[@track_id]
			@song = Gosu::Song.new(@tracks[@track_id].location)
			@song.play(false)
		rescue
			puts('Song retrieval - error')
		end	
  	end

	def display_options(titles, xpos)
		index = 0
		while (index < titles.length)
			@button_font.draw_text("#{titles[index]}", xpos, 105 + index*20, ZOrder::UI, 0.15, 0.15, BLACK, mode=:default)
			index += 1
		end
	end

	def draw_media_controller
		# song media controls 
		@btn_play = [Gosu::Image.new("image_ui/play.png"), Gosu::Image.new("image_ui/play_highlight.png")]
		@btn_pause = [Gosu::Image.new("image_ui/pause.png"), Gosu::Image.new("image_ui/pause_highlight.png")]
		@btn_playBack = [Gosu::Image.new("image_ui/playbefore.png"), Gosu::Image.new("image_ui/playbefore_highlight.png")]
		@btn_playNext = [Gosu::Image.new("image_ui/playnext.png"), Gosu::Image.new("image_ui/playnext_highlight.png")]
		@btn_playBack[0].draw(300, 675, ZOrder::UI)
		@btn_pause[0].draw(350, 675, ZOrder::UI)
		@btn_play[0].draw(400, 675, ZOrder::UI)
		@btn_playNext[0].draw(450, 675, ZOrder::UI)
	end

	# display stats based on current album and selected song
	def display_stat_window
		# must be displayed if @current_song (same as song) is known
		if (@current_song != nil)
			@info_font.draw_text("Now playing: #{@current_song.title}", 205, 605, ZOrder::UI, 0.2, 0.2, WHITE, mode=:default)

			# check if there is artwork
			if (@current_folder.artwork.bmp != nil)
				@current_folder.artwork.bmp.draw(0, 600, ZOrder::PLAYER)
			end
		end
	end

	# draw_rectangle
	def draw_rectangle(loc_x, loc_y, scale_x, scale_y, color)
		Gosu.draw_rect(loc_x, loc_y, scale_x, scale_y, color, ZOrder::BACKGROUND, mode=:default)
	end

	def draw_btn_highlight(btns, leftX, rightX, scale_x)
		index = 0
		while (index < btns)
			topY = 105 + index*20
			bottomY = 120 + index*20
			if (mouse_over_area(leftX, rightX, topY, bottomY))
				draw_rectangle(leftX, topY - 5, scale_x, 20, GRAY)
			end
			index += 1
		end
	end

	def draw_media_controller_highlight
		# highlight media controllers
		# use media controller highlight png
		# number of btns for mediaController fixe unless added new increment 1
		if mouse_over_area(300 + 0*50, 350 + 0*50, 675, 725)
			@btn_playBack[1].draw(300, 675, ZOrder::INTERACT)
		end
		if mouse_over_area(300 + 1*50, 350 + 1*50, 675, 725)
			@btn_pause[1].draw(350, 675, ZOrder::INTERACT)
		end
		if mouse_over_area(300 + 2*50, 350 + 2*50, 675, 725)
			@btn_play[1].draw(400, 675, ZOrder::INTERACT)
		end
		if mouse_over_area(300 + 3*50, 350 + 3*50, 675, 725)
			@btn_playNext[1].draw(450, 675, ZOrder::INTERACT)
		end
	end
	
	def draw_highlight
		draw_media_controller_highlight() # media controls
		draw_btn_highlight(@int_btn, 0, 200, 200) # albums
		if (@track_display == true)
			draw_btn_highlight(@track_titles.length, 200, 600, 400) # tracks
		end
		if (@window_mode != Button_type::NONE)
			if (mouse_over_area(0, 200, 560, 600))
				draw_rectangle(0, 560, 200, 40, GRAY) # back button
			end
		end
	end

	# manages all left menu interactions and buttons GUI
	def draw_left_menu
		if (@window_mode == Button_type::NONE)
			@info_font.draw_text_rel('Menu', 100, 50, ZOrder::UI, 0.5, 0.5, 0.3, 0.3, BLACK)
			@button_font.draw_text("Display All Albums", 5, 105 + 0*20, ZOrder::UI, 0.15, 0.15, BLACK, mode=:default)
			@button_font.draw_text("Playlists", 5, 105 + 1*20, ZOrder::UI, 0.15, 0.15, BLACK, mode=:default)
		elsif (@window_mode == Button_type::ALBUM)
			@info_font.draw_text_rel('Albums', 100, 50, ZOrder::UI, 0.5, 0.5, 0.3, 0.3, BLACK)
			@info_font.draw_text_rel('Tracks', 400, 50, ZOrder::UI, 0.5, 0.5, 0.3, 0.3, BLACK)
			@button_font.draw_text_rel('Return to Menu', 100, 580, ZOrder::UI, 0.5, 0.5, 0.2, 0.2, BLACK)
			display_options(@folder_titles, 5)
		elsif (@window_mode == Button_type::PLAYLIST)
			@info_font.draw_text_rel('Playlists', 100, 50, ZOrder::UI, 0.5, 0.5, 0.3, 0.3, BLACK)
			@info_font.draw_text_rel('Tracks', 400, 50, ZOrder::UI, 0.5, 0.5, 0.3, 0.3, BLACK)
			@button_font.draw_text_rel('', 100, 580, ZOrder::UI, 0.5, 0.5, 0.2, 0.2, BLACK)
			@button_font.draw_text_rel('Return to Menu', 100, 580, ZOrder::UI, 0.5, 0.5, 0.2, 0.2, BLACK)
			display_options(@folder_titles, 5)
		end
	end

	# Draws the album images and the track list for the selected album
	def draw
		# layout
		draw_rectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, WHITE) # background
		draw_rectangle(0, 0, 600, 100, TOP_COLOR) # top UI box
		draw_rectangle(200, 0, 2, 800, GRAY) # line split window; fixed unless new feature
		draw_rectangle(0, 600, 600, 200, BOTTOM_COLOR) # artwork window box
		draw_rectangle(0, 600, 200, 200, BLUE) # status window box

		# interactive UI
		draw_media_controller()
		draw_left_menu()
		draw_highlight()
		display_stat_window()
		
		if (@track_display == true && @window_mode == Button_type::ALBUM)
			draw_rectangle(0, @btn_folder[:topY] - 5, 200, 20, GREEN) 
			display_options(@track_titles, 205)
		end

		if (@track_display == true && @window_mode == Button_type::PLAYLIST) # on playlist press display 
			if (@select_mode != Button_select::ADD_TRACK)
				@button_font.draw_text_rel('Add Tracks', 400, 580, ZOrder::UI, 0.5, 0.5, 0.2, 0.2, BLACK)
				draw_rectangle(0, @btn_folder[:topY] - 5, 200, 20, GREEN) 
				display_options(@track_titles, 205)
			else
				@button_font.draw_text_rel('Right Click to Finalise, Left Click to reset', 400, 580, ZOrder::UI, 0.5, 0.5, 0.2, 0.2, BLACK)
				draw_rectangle(0, @btn_folder[:topY] - 5, 200, 20, GREEN)
				draw_rectangle(200, 560, 400, 40, GREEN)
				display_options(@track_titles, 205)
			end
		end

		if (@select_mode == Button_select::TRACK) # track button_down
			draw_rectangle(200, @btn_tracks[@track_id][:topY] - 5, 600, 20, GREEN)
		end
	end
	
	# checks options btn positions in left panel
	def btn_folder_handler(folders)
		folder_no = 0
		btn_folders = Buttons::btn_check_panel('left', folders.length)
		while (folder_no < folders.length)
			btn_folder = btn_folders[folder_no]
			if (mouse_over_area(btn_folder[:rightX], btn_folder[:leftX], btn_folder[:topY], btn_folder[:bottomY]))
				@folder_id = folder_no
				@btn_folder = btn_folder
				return true
				break
			end
			folder_no += 1
		end
	end
	
	# checks options btn positions in right panel
	def btn_track_handler(tracks)
		track_no = 0
		btn_tracks = Buttons::btn_check_panel('right', tracks.length)
		while (track_no < tracks.length)
			btn_track = btn_tracks[track_no] 
			if (mouse_over_area(btn_track[:rightX], btn_track[:leftX], btn_track[:topY], btn_track[:bottomY]))
				puts("track #{track_no} selected")
				@track_id = track_no
				@btn_tracks = btn_tracks
				return true
				break				
			end
			track_no += 1
		end
	end

	def button_down(id)
		case id
	    when Gosu::MsLeft
			@btn_selected = true
			# select feature btn from menu
			if (@window_mode == Button_type::NONE)
				if (mouse_over_area(0, 200, 105 + 0*20, 120 + 0*20))
					@window_mode = Button_type::ALBUM
					@btn_selected =	false
					@folder_titles.clear
					@int_btn = @albums.length
					@albums.each {|val| @folder_titles << val.title.chomp}
				elsif (mouse_over_area(0, 200, 105 + 1*20, 120 + 1*20))
					@window_mode = Button_type::PLAYLIST
					@btn_selected = false
					@folder_titles.clear
					@int_btn = @playlists.length
					@playlists.each {|val| @folder_titles << val.title.chomp}
				end
			end

			# ALBUMS
			if (@window_mode == Button_type::ALBUM && @btn_selected)
				@btn_selected =	false
				if (btn_folder_handler(@albums))
					@select_mode = Button_select::ALBUM
					@track_titles.clear
					@current_folder = @albums[@folder_id]
					@track_display = true
					@tracks = @albums[@folder_id].tracks
					@tracks.each {|track| @track_titles << track.title.chomp}
					@int_btn_tracks = @tracks.length
					puts("folder #{@folder_id} selected")
				end
			end

			# PLAYLST
			if (@window_mode == Button_type::PLAYLIST && @btn_selected)
				@btn_selected =	false
				if (btn_folder_handler(@playlists))
					@select_mode = Button_select::PLAYLIST
					@track_titles.clear
					if (@tracks != nil)
						@tracks.clear
					end
					@playlists = Persist_store::read_store('playlists')
					@current_folder = @playlists[@folder_id]
					@track_display = true
					@tracks = @playlists[@folder_id].tracks
					@tracks.each {|track| @track_titles << track.title.chomp}
					@int_btn_tracks = @tracks.length
					puts("folder #{@folder_id} selected")
				end
			end

			# ADD TRACK
			if (mouse_over_area(200, 600, 560, 600))
				@select_mode = Button_select::ADD_TRACK
				if (@song != nil)
					if (@song.playing?)
						@song.stop
					end
				end

				if (mouse_over_area(200, 600, 560, 600) && @select_mode )
					puts("hello")
				end

				# reset
				@add_tracks.clear
				@track_titles.clear
				@tracks.clear

				# get all tracks in folders
				@albums.each {|val|
					val.tracks.each {|track|
						@tracks << track
						@add_options << track
						@track_titles << track.title
					}
				}
				@int_btn_tracks = @track_titles.length
			end

			# TRACKS
			if (@track_display)
				if (@select_mode != Button_select::ADD_TRACK)
					if (btn_track_handler(@tracks))
						@select_mode = Button_select::TRACK
						playTrack()
					end
				else
					# add tracks to playlist
					if (btn_track_handler(@tracks))
						# check if array has elements
						# if true then validate for existing tracks
						# when adding track
						if (@add_tracks.empty?)
							@add_tracks << @tracks[@track_id]
						else
							exist = false
							@add_tracks.each {|track|
								if (track == @tracks[@track_id])
									puts("track #{@tracks[@track_id].title} exist")
									exist = true
								end
							}

							# add selected track when none exist
							if (exist == false)
								puts("success")
								@add_tracks << @tracks[@track_id]
							end
						end
					end
				end
			end

			# media controllers
			if (@song != nil && @track_id != nil)
				if (mouse_over_area(300,350,675,725)) # play back song
					puts("playback")
					if (@track_id > 0)
						@track_id -= 1
						playTrack()
					end
				end
				if (mouse_over_area(350,400,675,725)) # pause song
					puts("pause")
					if (@song.playing?)
						@song.pause
					end
				end
				if (mouse_over_area(400,450,675,725)) # play song
					puts("play")
					if (@song.paused?)
						@song.play
					end
				end
				if (mouse_over_area(450,500,675,725)) # play next song
					puts("playNext")
					if (@track_id < @tracks.length - 1)
						@track_id += 1
						playTrack()
					end
				end
			end

			# btn return to menu
			# reset Select and Window mode to NONE when in Menu Window
			if (@window_mode != Button_type::NONE)
				if (mouse_over_area(0, 200, 560, 600))
					@int_btn = 2
					@track_display = false
					@select_mode = Button_select::NONE
					@window_mode = Button_type::NONE
				end
			end
		when Gosu::MsRight
			# Finalise adding track to a playlist
			if (mouse_over_area(200, 600, 560, 600))
				# reset to original setting
				@select_mode = Button_select::PLAYLIST
				@track_titles.clear
				@playlists = Persist_store::read_store('playlists')

				# add tracks to playlist
				@add_tracks.each {|track|
					@playlists[@folder_id].tracks << track
				}

				@tracks = @playlists[@folder_id].tracks
				@tracks.each {|track| @track_titles << track.title.chomp}
				@int_btn_tracks = @tracks.length

				# https://stackoverflow.com/questions/26906806/hash-map-in-ruby-is-storing-key-value-pair-automatically
				# store playlist in persist store
				data = Hash.new(0)
				@tracks.each {|track|
					data [track.title] = track.location
				}
				
				Persist_store::write_store(@playlists[@folder_id].title, data)
				puts (data)
			end
	    end	
	end

	# Detects if a 'mouse sensitive' area has been clicked on
  	# i.e either an album or a track. returns true or false
  	def mouse_over_area(leftX, rightX, topY, bottomY)
		if ((mouse_x > leftX and mouse_x < rightX) and (mouse_y > topY and mouse_y < bottomY))
			true
		else
			false
		end
  	end

	# Not used? Everything depends on mouse actions.
	def update
		timeNow = update_interval
		if (@time_delay > 66.6664)
			@time_delay = 0
			if (@select_mode == true)
				@select_mode = false
			end
		else
			@time_delay += timeNow
		end
	end

	def needs_cursor?; true; end
end

# Show is a method that loops through update and draw
MusicPlayerMain.new.show if __FILE__ == $0

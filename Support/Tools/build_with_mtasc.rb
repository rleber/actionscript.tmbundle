#!/usr/bin/env ruby
#
# Build - compile ActionScript using MTASC
#
# Based on a command by Chris Sessions, Released on 2006-06-02.
# Copyright (c) 2006. MIT License.
# Modified by Ale Muñoz <http://bomberstudios.com> on 2006-11-24.
# Improvements suggested by Juan Carlos Añorga <http://www.juanzo.com/> on 2006-11-25
# 
# TODO: Use -main only when it's in the config

require "open3"
require "yaml"

require ENV['TM_SUPPORT_PATH'] + "/lib/exit_codes"
require ENV['TM_SUPPORT_PATH'] + "/lib/progress"
require ENV["TM_SUPPORT_PATH"] + "/lib/web_preview"

if !ENV['TM_PROJECT_DIRECTORY']
	html_header("Error!","Build With MTASC")
	puts "<h1>Do NOT run this if you don't have a project open...</h1>"
	html_footer
	TextMate.exit_show_html
end

if !File.exist?("#{ENV['TM_PROJECT_DIRECTORY']}/mtasc.yaml")
	html_header("Error!","Build With MTASC")
	puts "<h1>mtasc.yaml file missing</h1>"
	puts "<p>For the “Build With MTASC” command to work, you need to have a 'mtasc.yaml' file in your project's root folder. Use the “Install MTASC Support Files” command to create a default 'mtasc.yaml' file."
	html_footer
	TextMate.exit_show_html
end

def mtasc_compile
	Dir.chdir(ENV['TM_PROJECT_DIRECTORY'])
	yml = YAML.load(File.open('mtasc.yaml'))

	if !yml['mtasc_path']
		cmd = "\"#{ENV['TM_BUNDLE_SUPPORT']}/bin/mtasc\" "
	else
		cmd = "\"#{yml['mtasc_path']}\" "
	end
	cmd += " \"#{yml['app']}\" "
	cmd += " -version #{yml['player']} "
	# Standard Adobe Classes
	cmd += " -cp \"#{ENV['TM_BUNDLE_SUPPORT']}/lib/std/\" "
	cmd += " -cp \"#{ENV['TM_BUNDLE_SUPPORT']}/lib/std8/\" "
	# XTrace Classes
	cmd += " -cp \"#{ENV['TM_BUNDLE_SUPPORT']}/lib/\" "
	# User-provided Classpath
	if yml['classpaths']
		cmd += " -cp \"#{yml['classpaths'].join('" -cp "')}\" "
	end
	# Use XTrace for debugging
	if !yml['trace']
		# Open XTrace...
		`open "$TM_BUNDLE_SUPPORT/bin/XTrace.app"`
		cmd += " -pack com/mab/util "
		cmd += " -trace com.mab.util.debug.trace "
	end
	if !File.exists? yml['swf']
		cmd += " -header #{yml['width']}:#{yml['height']}:#{yml['fps']} "
	else
		cmd += " -keep "
	end
	cmd += " -main "
	cmd += " -swf #{yml['swf']} "

	stdin, stdout, stderr = Open3.popen3(cmd)
	warnings = []
	errors = []

	while err = stderr.gets
		if err[0, 10] == 'Warning : '
			warnings.push(err.chomp)
		else
			m = /(.+):([0-9]+): characters ([0-9]+)/.match(err)
			if m != nil
				a = "txmt://open?url=file://#{ENV['TM_PROJECT_DIRECTORY']}/#{m[1]}&line=#{m[2]}&column=#{m[3].to_i + 1}"
				err = "<a href=\"#{a}\">#{err}</a>"
			end
			errors.push(err.chomp)
		end
	end
	if !errors.empty?
		html_header("Error!","Build With MTASC")
		puts '<h1>Errors:</h1>'
		puts "<p>#{errors.uniq.join('</p><p>')}</p>"
		html_footer
	end
	if !warnings.empty?
		html_header("Warning!","Build With MTASC")
		puts '<h1>Warnings:</h1>'
		puts "<p>#{warnings.uniq.join('</p><p>')}</p>"
		html_footer
	end
	if errors.empty? && warnings.empty?
		`open #{yml['preview']}` if yml["preview"]
	else
		TextMate.exit_show_html
	end
end

# compile with MTASC
TextMate.call_with_progress({:title => "MTASC", :message => "Compiling Classes"}) do
	mtasc_compile
end
require 'httparty'
require 'json'

module Vsts
  class StaleBranchData < Jekyll::Generator
    def generate(site)
      @site = site

      process_data
    end

    def process_data
      out_filename = File.join(Dir.pwd, '_data', 'stale_branches.json')
      file_exists = File.exists?(out_filename)
      if file_exists and File.mtime(out_filename) > (Time.now - 60 * 60)
        puts "#{out_filename} is reasonably current, aborting rebuild"
        return
      end

      stale_infos = fetch_stale_infos 'https://iusdev.visualstudio.com/DefaultCollection'
      write_to_data 'stale_branches.json', stale_infos
    end

    def fetch_stale_infos(collectionUrl)
      threshold = (Date.today - 14).to_time
      stale_infos = []

      repo_infos = get_json "#{collectionUrl}/_apis/git/repositories?api_version=1.0"
      repo_infos['value'].each do |repo|
        repo_info = get_json "#{repo['url']}/stats/branches"
        repo_info['value'].each do |branch_info|
          if branch_info[':name'] == 'develop' or branch_info['name'] == 'master'
            next
          end
          if Time.parse(branch_info['commit']['committer']['date']) < threshold
            stale_info = { :branch_name => branch_info['name'], :commit => branch_info['commit'], :repo => repo }
            puts stale_info.to_json
            stale_infos.push stale_info
          end
        end
      end

      stale_infos
    end

    def write_to_data(out_filename, out_data)
      out_data_json = JSON.pretty_generate(out_data)
      out_full_filename = File.join(Dir.pwd, '_data', out_filename)
      File.write(out_full_filename, out_data_json)
    end

    def get_json(url)
      auth = {:password => ENV['VSTS_TOKEN']}
      res = HTTParty.get(url, :basic_auth => auth)
      JSON.parse(res.body)
    end
  end
end
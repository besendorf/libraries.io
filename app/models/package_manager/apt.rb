module PackageManager
  class Apt < Base
  


    def self.project_names
      get("https://sources.debian.org/api/list/")["packages"].map {|x| x.values[0]}
    end

    def self.project(name)
      {
        name: name,
        page: get_html("https://packages.debian.org/stable/#{name}")
      }
    end

    def self.mapping(raw_project)
      {
        name:  raw_project[:name],
        #keywords_array:  raw_project[:page].css("#tags")
        licenses: find_license(raw_project[:name]),
        description:  raw_project[:page].css("#pdesc p")&.children[0]&.text,
        licenses: find_attribute(raw_project[:page], "License"),
        homepage: find_attribute(raw_project[:page], "Homepage"),
        repository_url: repo_fallback(repository_url(find_attribute(raw_project[:page], "Homepage")), find_attribute(raw_project[:page], "Homepage")),
      }
    end

    def self.versions(_raw_project, name)
      page = get_html("https://packages.debian.org/search?keywords=#{name}&searchon=names&exact=1&suite=all&section=all")
      #links = page.css("#psearchres li a")[0].attributes["href"].value
        {
          number: page.css("#psearchres li").map {|x| x.children.last.text.split(':')[0]},
          #published_at: nil #not availabe for debian
          # we could at original_license: here
        }
    end

    def self.one_version(raw_project, version_string)
      versions(raw_project, raw_project["name"])
        .find { |v| v[:number] == version_string }
    end

    def self.dependencies(name, version, mapped_project)
      page = get_html("https://tracker.debian.org/pkg/#{name}")
      a = page.css("#dtracker-package-left > div:nth-child(2) > div:nth-child(2) > ul:nth-child(1) > li > a")
      for b in a
        if b.text == version
          p_link = b.attributes["href"].value.sub!("/source","") #return the non-source package
        end
      end
      p_page = get_html(p_link)
      p_page.css("#pdeps a").children.map {|x| x.text} #TODO handle OR dependecies

      return [] unless json['dependencies']
      json['dependencies'].map do |dep_name, dep_version|
        {
          project_name: dep_name,
          requirements: dep_version.empty? ? '*' : dep_version,
          kind: 'runtime',
          platform: self.name.demodulize
        }
      end
    rescue
      []
    end

    def self.package_link(project, version = nil)
      "https://rubygems.org/gems/#{project.name}" + (version ? "/versions/#{version}" : "")
    end

    #copied from hackage
    def self.find_attribute(page, name)
      a = page.css("#content li").select { |t| t.css("a").text.to_s.start_with?(name) }.first
      a&.children[0]&.attributes["href"]&.value
    end


    def find_license(name)
      correctblock = false
      get("https://metadata.ftp-master.debian.org/changelogs//main/0/#{name}/stable_copyright").each_line do |line|
        case line
        when /^Files: */
          correctblock = true
          next
        when /^Copyright:/
          #do nothing
          next
        when /^License:/
          if correctblock
            return line.sub(/License:/,'')
          end
          next
        else
          correctblock = false
          next
        end
      end
    end

    def self.description(page)
      contents = page.css("#content p, #content hr").map(&:text)
      index = contents.index ""
      return "" unless index

      contents[0..(index - 1)].join("\n\n")
    end

    def self.repository_url(text)
      return nil unless text.present?

      match = text.match(/github.com\/(.+?)\.git/)
      return nil unless match

      "https://github.com/#{match[1]}"
    end
  end
end
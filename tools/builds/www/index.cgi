#!/usr/bin/ruby --encoding=utf-8:utf-8

# Build system web interface
# Copyright (C) Florian Negele

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

require 'fcgi'
require 'open3'
require 'socket'
require 'sqlite3'

Database = SQLite3::Database.new("#{__dir__}/builds.db")
# Database.execute 'create table if not exists builds (project text not null, target text not null, version text not null, status text not null, notification text, started real not null, updated real not null, output text not null, check (length (project) and length (target) and length (version) and status in ("Aborted", "Building", "Conflicted", "Failed", "Succeeded", "Timeout") and notification in ("Aborted", "Conflicted", "Failed", "Timeout")))'
# Database.execute 'create table if not exists links (project text not null, target text not null, url text not null, check (length (project) and length (target) and length (url)))'
# Database.execute 'create table if not exists sources (project text not null, hostname text not null, check (length (project) and length (hostname)))'
# Database.execute 'create table if not exists contacts (project text not null, address text not null, check (length (project) and length (address)))'
# Database.execute 'create table if not exists aliases (project text not null, name text not null, check (length (project) and length (name)))'
Database.busy_timeout 10000

requests = 0
FCGI.each_cgi('html4') do |cgi|

# validate parameters

project = cgi['project']; if project.empty? then project = nil end
target = cgi['target']; if target.empty? then target = nil end
version = cgi['version']; if version.empty? then version = nil end

# update database

def cgi.href(project = nil, target = nil, version = nil, suffix = nil)
	"#{request_method == 'POST' || has_key?('format') ? 'http://builds.cas.inf.ethz.ch/' : '/'}#{project && "#{CGI.escape(project)}/"}#{target && "#{CGI.escape(target)}/"}#{version && "#{CGI.escape(version)}/"}#{suffix}"
end

def cgi.notify(project, target, version, status, output)
	Database.query('select address from contacts where project = :project', project: project).each { |address| Open3.capture2("notify \"#{address[0]}\" \"[#{project} - #{target} Version #{version}] Build #{status.downcase}\"", stdin_data: (output.empty? ? '' : "Output:\n#{output}\n\n") << "Link:\n#{href(project, target, version)}") }
end

begin
	if cgi.request_method == 'POST' then
		status = cgi['status']; output = cgi['output'].gsub(/\e\[\d+(;\d+)*m/, '').tr("\x00-\x08\x0c-\x1f\x7f", '').strip.lines.last(1000).join
		if Database.query('select hostname from sources where project = :project', project: project).count { |source| cgi.remote_addr == IPSocket.getaddress(source[0]) rescue false } == 0 then cgi.out('status' => 'FORBIDDEN') { '' }; next end
		Database.execute 'update builds set status = :status, notification = case :status when "Succeeded" then null else notification end, started = case :status when "Building" then julianday ("now") else started end, updated = julianday ("now"), output = :output where project = :project and target = :target and version = :version', project: project, target: target, version: version, status: status, output: output
		if Database.changes == 0 then Database.execute 'insert into builds values (:project, :target, :version, :status, null, julianday ("now"), julianday ("now"), :output)', project: project, target: target, version: version, status: status, output: output end
		Database.execute 'update builds set status = "Timeout", output = "", updated = julianday ("now") where status = "Building" and julianday ("now") - started > 0.2'
		Database.query('select project, target, version, status, output from builds where status not in ("Building", "Succeeded") and (notification is null or notification != status)').each { |build| cgi.notify(build[0], build[1], build[2], build[3], build[4]) }
		Database.execute 'update builds set notification = status where status not in ("Building", "Succeeded") and (notification is null or notification != status)'
		cgi.out { '' }; next
	else
		project = Database.get_first_value('select project from aliases where name = :project', project: project) || project
		timestamp = Database.get_first_value('select strftime ("%Y-%m-%d %H:%M:%f", updated) from builds where (:project is null or project = :project) and (:target is null or target = :target) order by updated desc limit 1', project: project, target: target)
		if !timestamp && project then cgi.out('status' => 'NOT_FOUND') { cgi.html { cgi.head { cgi.title { '404 Not Found' } } << cgi.body { cgi.h1 { 'Not Found' } << cgi.p { 'The requested URL was not found on this server.' } } } << "\n" }; next end
	end
rescue SQLite3::ReadOnlyException
	cgi.out('status' => 'FORBIDDEN') { '' }; next
rescue SQLite3::ConstraintException
	cgi.out('status' => 'BAD_REQUEST') { '' }; next
end

# render page

def cgi.url(project = nil, target = nil, version = nil, name = nil, suffix = nil, onlick = nil)
	a(href: href(project, target, version, suffix), onclick: onlick) { name ? name : CGI.escapeHTML(version ? version : target ? target : project ? project : 'Overview') }
end

def cgi.log(project = nil, target = nil)
	limit = target ? 20 : 10; offset = (self['page'].to_i - 1) * limit; if offset < 0 then offset = 0 end; predecessor = offset - limit; successor = offset + limit
	count = Database.get_first_value('select count (*) from builds where (:project is null or project = :project) and (:target is null or target = :target)', project: project, target: target); started = nil; updated = nil
	table(class: 'log') { tr { (project ? '' : th { 'Project' } ) << (target ? '' : th { 'Target' } ) << th { 'Version' } << th(colspan: 2) { 'Build Started&#9660;' } << (target ? th(colspan: 2) { 'Last Update' } : '') << (project ? th { 'Duration' } << th { 'Output' } : '') << th { 'Status' } } <<
		Database.query('select project, target, version, date (started, "localtime"), strftime (case when :target is null then "%H:%M" else "%H:%M:%S" end, started, "localtime"), date (updated, "localtime"), strftime (case when :target is null then "%H:%M" else "%H:%M:%S" end, updated, "localtime"), time (case status when "Building" then julianday ("now") else updated end - started + 0.5), output, status from builds where (:project is null or project = :project) and (:target is null or target = :target) order by started desc, project, target limit :limit offset :offset', project: project, target: target, limit: limit, offset: offset).collect { |build|
		tr { (project ? '' : td { url(build[0]) } ) << (target ? '' : td { url(build[0], build[1]) } ) << td { url(build[0], build[1], build[2]) } << td { build[3] != started ? started = build[3] : '&rdquo;' } << td { build[4] } << (target ? td { build[5] != updated ? updated = build[5] : '&rdquo;' } << td { build[6] } : '') << (project ? td(class: build[9] == 'Building' && 'timer') { build[7] } << td { build[8].empty? ? build[9] == 'Building' ? div(class: 'busy') : '&mdash;' : url(build[0], build[1], build[2], "#{lines = build[8].lines.size} #{lines == 1 ? 'line' : 'lines'}", '#output') } : '') << td(class: "status #{build[9]}") { url(build[0], build[1], build[2], build[9], '#output') } }
	}.join << ((offset < count ? count : offset) + 1 .. offset + limit).collect { tr { td { '&nbsp;' } } }.join <<
	tr { td(class: 'pagination', colspan: target ? 8 : project ? 7 : 6) { (predecessor >= 0 && offset < count ? url(project, target, nil, "&laquo; #{predecessor + 1} &ndash; #{offset}", predecessor / limit + 1, 'return load(this)') << ' | ' : '') <<
	(offset < count ? "Builds #{offset + 1} &ndash; #{successor < count ? successor : count}" : 'No Builds') <<
	(successor < count ? ' | ' << url(project, target, nil, "#{successor + 1} &ndash; #{successor + limit < count ? successor + limit : count} &raquo;", successor / limit + 1, 'return load(this)') : '') } } }
end

def cgi.info(project, target = nil)
	latest = nil; table { tr { (target ? '' : th { 'Target&#9660;' } << th { 'Builds' } ) << th { "Latest#{target && '&#9660;'}" } << th { 'Version' } << th { 'Duration' } << th { 'Status' } } <<
	(target ? Database.query('select target, null, date (started, "localtime"), version, time (case status when "Building" then julianday ("now") else updated end - started + 0.5), status from builds where :project = project and :target = target order by started desc limit 5', project, target) : Database.query('select target, builds, date (latest, "localtime"), version, time (case status when "Building" then julianday ("now") else updated end - started + 0.5), status from (select target as name, count (*) as builds, max (started) as latest from builds group by target) join builds on target = name and started = latest where project = :project order by target', project)).collect { |info|
	tr { (target ? '' : td { url(project, info[0]) } << td { info[1] } ) << td { info[2] != latest ? latest = info[2] : '&rdquo;' } << td { url(project, info[0], info[3]) } << td(class: info[5] == 'Building' && 'timer') { info[4] } << td(class: "status #{info[5]}") { url(project, info[0], info[3], info[5], '#output') } } }.join }
end

case cgi['format']
when 'rss'
	cgi.out('type' => 'application/rss+xml', 'charset' => 'UTF-8') { '<?xml version="1.0"?><rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel>' <<
	"<title>CAS Builds#{project && " - #{CGI.escapeHTML(project)}"}#{target && " - #{CGI.escapeHTML(target)}"}</title><link>http://builds.cas.inf.ethz.ch</link><description>CAS Build System</description>" <<
	"<atom:link href=\"#{cgi.href(project && cgi['project'], target, nil, 'feed')}\" rel=\"self\" type=\"application/rss+xml\"/>#{timestamp && "<lastBuildDate>#{DateTime.parse(timestamp).rfc822}</lastBuildDate>"}" <<
	Database.query('select project, target, version, status, datetime (updated), time (case status when "Building" then julianday ("now") else updated end - started + 0.5), output from builds where (:project is null or project = :project) and (:target is null or target = :target) and updated >= julianday (:latest, "localtime", "start of day", "-7 days", "utc") order by updated desc, started desc, project, target', project: project, target: target, latest: timestamp).collect { |build|
		"<item><title>#{project ? '' : "#{CGI.escapeHTML(build[0])} - "}#{target ? '' : "#{CGI.escapeHTML(build[1])} "}Version #{CGI.escapeHTML(build[2])}: #{build[3]}</title>" <<
		"<link>#{cgi.href(build[0], build[1], build[2])}</link><guid>#{cgi.href(build[0], build[1], build[2], "##{build[3]}")}</guid>" <<
		"<pubDate>#{DateTime.parse(build[4]).rfc822}</pubDate><description>#{CGI.escapeHTML("Duration: #{build[5]}" << cgi.pre { CGI.escapeHTML(build[6]) } )}</description></item>"
	}.join << "</channel></rss>\n" }; next
when 'timestamp'
	cgi.out('type' => 'text/plain', 'expires' => Time.now) { timestamp.to_s }; next
when 'log'
	cgi.out('type' => 'text/plain') { cgi.log(project, target) }; next
when 'info'
	cgi.out('type' => 'text/plain') { cgi.info(project) }; next
else
	requests += 1
end

def cgi.overview(project = nil, target = nil)
	overview = Database.get_first_row('select case when :project is null then count (distinct project) else null end, case when :project is null then count (distinct project || target) else count (distinct target) end, case when :project is null then count (distinct project || version) else count (distinct version) end, count (*) from builds where (:project is null or project = :project) and (:target is null or target = :target)', project: project, target: target)
	(project ? '' : label { "Projects: #{overview[0]}" } ) << (target ? '' : label { "Targets: #{overview[1]}" } << label { "Versions: #{overview[2]}" } ) << label { "Builds: #{overview[3]}" }
end

def cgi.statuses(project = nil, target = nil)
	statuses = Database.query('select status, count (*) from builds where (:project is null or project = :project) and (:target is null or target = :target) group by status order by status desc', project: project, target: target)
	statuses.collect { |status| label { "#{status[0]}: #{span(class: "status #{status[0]}") { status[1] }}" } }.join
end

def cgi.detail(project, target = nil)
	div(class: 'detail') { h3 { url(project, target) } << (target ? '' : div { overview(project, target) } << div { statuses(project, target) } ) << info(project, target) }
end

def cgi.versions(project)
	versions = Database.query('select version from builds where project = :project group by version order by max (started) desc limit 8', project: project).collect { |version| version[0] }
	div(class: 'detail') { h3 { 'Latest Builds by Version' } << table { tr { th { 'Target&#9660;' } << versions.collect { |version| th { version } }.join } <<
	Database.query("select target, #{versions.collect { 'max (case version when ? then status end)' }.join(', ')} from builds where project = :project group by target order by target", versions, project: project).collect { |target|
		name = target[0]; tr { td { url(project, target.shift) } << target.each_with_index.collect { |status, index| status ? td(class: "status #{status}") { url(project, name, versions[index], status, '#output') } : td { '&mdash;' } }.join }
	}.join << tr { td << Database.get_first_row("select #{versions.collect { 'sum (version = ?)' }.join(', ')} from builds where project = :project", versions, project: project).collect { |builds| td(class: 'pagination') { builds } }.join } } }
end

def cgi.legend(statuses)
	statuses.collect { |status| span(class: status) { '&emsp;' } << " #{status}" }.join('&emsp;')
end

def cgi.coverage(project)
	statuses = Database.query('select status from builds where project = :project group by status order by status desc', project: project).collect { |status| status[0] }
	maximum = Database.get_first_value('select max (builds) from (select count (*) as builds from builds where project = :project group by target)', project: project)
	div(class: 'detail') { h3 { 'Build Coverage' } << table { tr { th { 'Target' } << th { 'Builds' } << th { 'Distribution&#9660;' } } <<
	Database.query("select target, count (*), #{statuses.collect { 'sum (status = ?)' }.join(', ')} from builds where project = :project group by target order by count (*) desc, target", statuses, project: project).collect { |target|
		total = target[1]; tr { td { url(project, target.shift) } << td { target.shift } << td { target.each_with_index.collect { |builds, index| builds == 0 ? '' : span(class: "bar #{statuses[index]}", style: "width:#{(builds * 30.0 / maximum).round(2)}em;", title: "#{builds}/#{total} #{statuses[index]} (#{(builds * 100.0 / total).round(1)}%)") { '&nbsp;' } }.join << (total == maximum ? '' : span(class: 'bar', style: "width:#{((maximum - total) * 30.0 / maximum).round(2)}em;") { '&nbsp;' } ) } }
	}.join << tr { td << td << td(class: 'pagination') { legend(statuses) } } } }
end

def cgi.activity(project = nil, target = nil)
	start = Database.get_first_value('select julianday (date (max (started)), "localtime", "start of month", "-11 months", "utc") from builds where (:project is null or project = :project) and (:target is null or target = :target)', project: project, target: target)
	statuses = Database.query('select status from builds where started >= :start and (:project is null or project = :project) and (:target is null or target = :target) group by status order by status desc', project: project, target: target, start: start).collect { |status| status[0] }
	activity = Database.query("select date (date (started, 'localtime'), 'start of month') as month, count (*)#{statuses.collect { ', sum (status = ?)' }.join} from builds where started >= :start and (:project is null or project = :project) and (:target is null or target = :target) group by month order by month", statuses, project: project, target: target, start: start).to_a
	maximum = activity.collect { |month| month[1] }.max.to_i; if maximum == 0 then maximum = 1 end; unit = (target ? 9 : project ? 11 : 12) * 1.4 / maximum
	increment = 1; index = 0; while increment * unit < 2 do increment = index % 3 == 1 ? increment * 5 / 2 : increment * 2; index += 1 end; if increment > maximum then increment = maximum end
	div(class: 'detail') { h3 { 'Recent Activity' } << table {
		tr { th << activity.collect { |month| month = DateTime.parse(month.shift); th(title: month.strftime('%B %Y')) { month.strftime('%b') } }.join } <<
		tr(class: 'histogram') { td { (0 - maximum / increment .. -1).collect { |step| span(class: 'step', style: "height:#{(increment * unit).round(2)}em;") { -step * increment } }.join } << activity.collect { |month| total = month.shift; td { month.each_with_index.collect { |builds, index| builds == 0 ? '' : span(class: "bin #{statuses[index]}", style: "height:#{(builds * unit).round(2)}em;", title: "#{builds}/#{total} #{statuses[index]} (#{(builds * 100.0 / total).round(1)}%)") { } }.join } }.join } <<
		tr { activity.empty? ? td { 'None' } : td << td(class: 'pagination', colspan: activity.count) { legend(statuses) } }
	} }
end

def cgi.statistics(project = nil, target = nil)
	statistics = Database.query("select date (min (day)) as 'First Build', date (max (day)) as 'Latest Build', round (count (*) / (max (day) - min (day) + 1.0), 1) as 'Builds per Day', round (count (*) / (max (month) - min (month) + 1.0), 1) as 'Builds per Month', #{project ? '' : "round (count (*) * 1.0 / count (distinct project), 1) as 'Builds per Project', "}#{target ? '' : "round (count (*) * 1.0 / count (distinct target), 1) as 'Builds per Target', round (count (*) * 1.0 / count (distinct version), 1) as 'Builds per Version', "}time (max (duration) + 0.5) as 'Longest Build', time (min (duration) + 0.5) as 'Shortest Build', time (avg (duration) + 0.5) as 'Average Duration', round (sum (duration) * 24.0, 1) || 'h' as 'Overall Duration', round (sum (success) * 100.0 / count (*), 1) || '%' as 'Success Rate', round (sum (not success) * 100.0 / count (*), 1) || '%' as 'Failure Rate' from (select julianday (started, 'localtime') as day, strftime ('%Y', started, 'localtime') * 12 + strftime ('%m', started, 'localtime') as month, project, case when :project is null then project || target else target end as target, case when :project is null then project || version else version end as version, case status when 'Building' then null else updated - started end as duration, case status when 'Building' then null else status = 'Succeeded' end as success from builds where (:project is null or project = :project) and (:target is null or target = :target))", project: project, target: target)
	div(class: 'detail') { h3 { 'Statistics' } << table(class: 'statistics') { value = statistics.next; statistics.columns.each_with_index.collect { |column, index| tr { th { "#{column}:" } << td { value[index] ? value[index] : '&mdash;' } } }.join } } ensure statistics.close
end

if !project then
	title = 'Overview'
	summary = cgi.div { cgi.overview } << cgi.div { cgi.statuses } << cgi.log
	projects = Database.query('select project from builds group by project order by project').collect { |project| project[0] }
	contents = cgi.div { projects.collect { |project| cgi.detail(project) }.join } << cgi.div { cgi.activity << cgi.statistics }
	navigation = projects.collect { |project| cgi.url(project) }.join(' | ')
elsif !target then
	title = CGI.escapeHTML(project)
	summary = cgi.div { cgi.overview(project) } << cgi.div { cgi.statuses(project) } << cgi.log(project)
	targets = Database.query('select target from builds where project = :project group by target order by target', project: project).collect { |target| target[0] }
	contents = cgi.div { targets.collect { |target| cgi.detail(project, target) }.join } << cgi.div { cgi.versions(project) << cgi.coverage(project) } << cgi.div { cgi.activity(project) << cgi.statistics(project) }
	links = Database.query('select url, target from links where project = :project order by target', project: project).collect { |link| cgi.a(href: link[0]) { CGI.escapeHTML(link[1]) } }.join(' &ndash; ')
	predecessor = Database.get_first_value('select project from builds where project < :project group by project order by project desc limit 1', project: project)
	successor = Database.get_first_value('select project from builds where project > :project group by project order by project asc limit 1', project: project)
	navigation = (predecessor ? cgi.url(predecessor, nil, nil, "&laquo; #{CGI.escapeHTML(predecessor)}") << ' | ' : '') << cgi.url << (links.empty? ? '' : " | #{links}") << (successor ? ' | ' << cgi.url(successor, nil, nil, "#{CGI.escapeHTML(successor)} &raquo;") : '')
elsif !version then
	title = CGI.escapeHTML("#{project} - #{target}")
	summary = cgi.overview(project, target) << cgi.statuses(project, target)
	contents = cgi.log(project, target) << cgi.activity(project, target) << cgi.statistics(project, target)
	link = Database.get_first_value('select url from links where project = :project and target = :target', project: project, target: target)
	predecessor = Database.get_first_value('select target from builds where project = :project and target < :target group by target order by target desc limit 1', project: project, target: target)
	successor = Database.get_first_value('select target from builds where project = :project and target > :target group by target order by target asc limit 1', project: project, target: target)
	navigation = (predecessor ? cgi.url(project, predecessor, nil, "&laquo; #{CGI.escapeHTML(predecessor)}") << ' | ' : '') << cgi.url(project) << (link ? ' | ' << cgi.a(href: link) { CGI.escapeHTML(target) } : '') << (successor ? ' | ' << cgi.url(project, successor, nil, "#{CGI.escapeHTML(successor)} &raquo;") : '')
else
	title = CGI.escapeHTML("#{project} - #{target} Version #{version}")
	overview = Database.get_first_row('select datetime (started, "localtime"), datetime (updated, "localtime"), time (case status when "Building" then julianday ("now") else updated end - started + 0.5), status, output from builds where project = :project and target = :target and version = :version', project: project, target: target, version: version)
	predecessor = Database.get_first_value('select version from builds where project = :project and target = :target and datetime (started, "localtime") < :started order by started desc limit 1', project: project, target: target, started: overview[0])
	successor = Database.get_first_value('select version from builds where project = :project and target = :target and datetime (started, "localtime") > :started order by started asc limit 1', project: project, target: target, started: overview[0])
	resolution = overview[3] == 'Failed' && (successor && Database.get_first_value('select status from builds where project = :project and target = :target and version = :version', project: project, target: target, version: successor) || "Unresolved")
	summary = cgi.div { cgi.label { "Build Started: #{overview[0]}" } << cgi.label { "Last Update: #{overview[1]}" } } << cgi.div { cgi.label { 'Duration: ' << cgi.span(class: overview[3] == 'Building' && 'timer') { overview[2] } } << cgi.label { 'Status: ' << cgi.span(class: "status #{overview[3]}") { overview[3] } << (resolution ? '&#9658;' << cgi.span(class: "status #{resolution}", title: successor && "Resolution of Version #{CGI.escapeHTML(successor)}") { successor ? cgi.url(project, target, successor, resolution) : resolution } : '') } }
	contents = overview[4].empty? && overview[3] == 'Building' ? cgi.div(id: 'output', class: 'busy') : cgi.div { cgi.textarea(id: 'output', cols: 70, rows: 10, readonly: true, disabled: overview[4].empty?) { CGI.escapeHTML(overview[4]) } }
	repository = version.match(/^\d+M?S?P?$/) && Database.get_first_value('select url from links where project = :project and target = "Repository"', project: project)
	page = Database.get_first_value('select count (*) / 20 + 1 from builds where project = :project and target = :target and datetime (started, "localtime") > :started', project, target, started: overview[0]).inspect
	navigation = (predecessor ? cgi.url(project, target, predecessor, "&laquo; Version #{CGI.escapeHTML(predecessor)}") << ' | ' : '') << "#{cgi.url(project)} &ndash; #{cgi.url(project, target, nil, nil, page)}" << (repository ? ' | ' << cgi.a(href: "#{repository}revisions/#{CGI.escape(version[/\d+/])}") { "Revision #{CGI.escapeHTML(version[/\d+/])}" } : '') << (repository && predecessor ? ' (' << cgi.a(href: "#{repository}diff?rev=#{CGI.escape(version[/\d+/])}&rev_to=#{CGI.escape(predecessor[/\d+/])}") { 'diff' } << ')' : '') << (successor ? ' | ' << cgi.url(project, target, successor, "Version #{CGI.escapeHTML(successor)} &raquo;") : '')
end

cgi.out {
	cgi.html {
		cgi.head {
			cgi.title { "#{title} - CAS Builds" } <<
			cgi.meta(name: 'rqid', content: requests) <<
			cgi.meta('http-equiv': 'content-type', content: 'text/html; charset=UTF-8') <<
			cgi.meta(name: 'viewport', content: 'width=device-width; initial-scale=1') <<
			cgi.link(rel: 'stylesheet', type: 'text/css', href: '/style.css', media: 'screen') <<
			cgi.link(rel: 'alternate', type: 'application/rss+xml', href: cgi.href(project, target, nil, 'feed'), title: "CAS Builds #{title} Feed") <<
			cgi.script(src: '/update.js', type: 'text/javascript')
		} <<
		cgi.body {
			cgi.div(id: 'header') { cgi.h1 { 'CAS Builds' } } << cgi.h2 { title } << cgi.div(id: 'summary') { summary } << contents << cgi.div { navigation } <<
			cgi.div(id: 'footer') { cgi.p { 'Copyright &copy; 2018 ' << cgi.a(href: 'http://cas.inf.ethz.ch') { 'CAS' } << Time.now.strftime(' using %Z (UTC%:z)') } } <<
			cgi.script(type: 'text/javascript') { "check (\"#{timestamp}\")" }
		}
	} << "\n"
}

end

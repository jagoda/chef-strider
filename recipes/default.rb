include_recipe "git"
include_recipe "nodejs"

strider_user = node[:strider][:user]
strider_group = node[:strider][:group]
home_directory = "/home/#{strider_user}"

install_directory = node[:strider][:directory]
if node[:strider][:data].nil?
	data_directory = File.join(install_directory, "data")
else
	data_directory = node[:strider][:data]
end
log_file = node[:strider][:log]

user strider_user do
	home home_directory
end
group strider_group do
	members strider_user
end
directory home_directory do
	owner strider_user
	group strider_group
end

directory install_directory do
	owner strider_user
	group strider_group
end

git install_directory do
	repository "https://github.com/Strider-CD/strider.git"
	revision "master"
	user strider_user
	group strider_group
end

execute "npm install" do
	cwd install_directory
	user strider_user
	group strider_group
	environment("HOME" => home_directory)
	notifies :restart, "service[strider]"
end

unless node[:strider][:plugins].nil?
	plugins = node[:strider][:plugins]
	unless plugins.kind_of?(Array)
		plugins = [ plugins ]
	end
	plugins.each do |plugin|
		name = File.basename(URI.parse(plugin).path, ".git")
		directory = File.join(install_directory, "node_modules", name)

		# Delete the directory first in case a default version of the plugin was
		# included with the base Strider code.
		directory directory do
			action :delete
		end

		git directory do
			repository plugin
			user strider_user
			group strider_group
		end

		execute "npm install" do
			cwd directory
			user strider_user
			group strider_group
			environment("HOME" => home_directory)
			notifies :restart, "service[strider]"
		end
	end
end

directory data_directory do
	owner strider_user
	group strider_group
end

file log_file do
	action :create_if_missing
	owner strider_user
	group strider_group
end

template File.join(install_directory, "strider.conf") do
	source "strider.conf"
	owner strider_user
	group strider_group

	unless node[:ec2].nil? or node[:strider][:port].nil?
		strider_url = "http://#{node[:ec2][:fqdn]}:#{node[:strider][:port]}/"
	else
		strider_url = node[:strider][:url]
	end

	variables(
		:bitbucket => node[:strider][:bitbucket],
		:data_directory => data_directory,
		:database => node[:strider][:database],
		:github => node[:strider][:github],
		:port => node[:strider][:port],
		:url => strider_url
	)
end

template "/etc/init/strider.conf" do
	source "upstart.conf"
	variables(
		:config_file => File.join(install_directory, "strider.conf"),
		:install_directory => install_directory,
		:log_file => log_file,
		:user => strider_user
	)
	notifies :restart, "service[strider]"
end

service "strider" do
	provider Chef::Provider::Service::Upstart
	action [ :enable, :start ]
end

unless node[:strider][:admin].nil?
	email = node[:strider][:admin][:email]
	password = node[:strider][:admin][:password]
	command = "node bin/strider addUser --email #{email} --password #{password} --admin"
	execute command do
		cwd install_directory
		user strider_user
		group strider_group
	end
end

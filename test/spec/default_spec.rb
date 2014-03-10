require "chefspec"
require "chefspec/berkshelf"

describe "strider::default" do

	DEFAULT_USER = "strider"
	DEFAULT_GROUP = "strider"
	HOME_DIRECTORY = "/home/strider"

	CONFIG_FILE = "strider.conf"
	DATA_DIRECTORY = "data"
	INSTALL_DIRECTORY = "/opt/strider"
	CONFIG_PATH = "#{INSTALL_DIRECTORY}/#{CONFIG_FILE}"
	DATA_PATH = "#{INSTALL_DIRECTORY}/#{DATA_DIRECTORY}"

	LOG_FILE = "/var/log/strider.log"

	STRIDER_REPOSITORY = "https://github.com/Strider-CD/strider.git"

	def validate_config (file, patterns)
		if not patterns.kind_of?(Array)
			patterns = [ patterns ]
		end

		patterns.each do |content|
			expect(chef_run).to render_file(file).with_content(content)
		end
	end

	def assert_npm_install (directory, user, group, home)
		# Need to manually search for the resource since ChefSpec matches only
		# by name.
		execute = chef_run.find_resources(:execute).find do |resource|
			resource.name === "npm install" && resource.cwd === directory
		end
		expect(execute).to_not be_nil
		expect(execute.user).to eq(DEFAULT_USER)
		expect(execute.group).to eq(DEFAULT_GROUP)
		expect(execute.environment).to include("HOME" => home)
		expect(execute).to notify("service[strider]").to(:restart)
	end

	def assert_plugin_installed (plugin)
		name = File.basename(URI.parse(plugin).path, ".git")
		directory = "#{INSTALL_DIRECTORY}/node_modules/#{name}"
		expect(chef_run).to delete_directory(directory)
		expect(chef_run).to sync_git(directory).with(
			repository: plugin,
			user: DEFAULT_USER,
			group: DEFAULT_GROUP
		)

		assert_npm_install(directory, DEFAULT_USER, DEFAULT_GROUP, HOME_DIRECTORY)
	end

	context "on Ubuntu 12.04" do

		UPSTART_CONFIG = "/etc/init/strider.conf"

		platform = "ubuntu"
		version = "12.04"

		context "using the default attributes" do

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version).converge(described_recipe)
			end

			it "ensures that git is installed" do
				expect(chef_run).to install_package("git")
			end

			it "installs Node.JS" do
				# FIXME: need to guarantee that Node can build native extensions
				# (seems like a bug in the 'nodejs' cookbook.
				expect(chef_run).to install_package("python")
				expect(chef_run).to install_package("g++")
				expect(chef_run).to install_package("make")
				expect(chef_run).to include_recipe("nodejs")
			end

			it "creates a 'strider' user" do
				expect(chef_run).to create_user(DEFAULT_USER)
				expect(chef_run).to create_group(DEFAULT_GROUP).with(
					members: [ DEFAULT_USER ]
				)
				expect(chef_run).to create_directory(HOME_DIRECTORY).with(
					owner: DEFAULT_USER,
					group: DEFAULT_GROUP
				)
			end

			it "loads the latest server code" do
				expect(chef_run).to create_directory(INSTALL_DIRECTORY).with(
					owner: DEFAULT_USER,
					group: DEFAULT_GROUP
				)

				expect(chef_run).to sync_git(INSTALL_DIRECTORY).with(
					repository: STRIDER_REPOSITORY,
					user: DEFAULT_USER,
					group: DEFAULT_GROUP
				)

				assert_npm_install(INSTALL_DIRECTORY, DEFAULT_USER, DEFAULT_GROUP, HOME_DIRECTORY)
			end

			it "configures the server to start on boot" do
				service_name = "strider"

				validate_config(UPSTART_CONFIG, [
					"setuid #{DEFAULT_USER}",
					"cd #{INSTALL_DIRECTORY}",
					". #{CONFIG_PATH}",
					"npm start >> #{LOG_FILE} 2>&1"
				])
				template = chef_run.template(UPSTART_CONFIG)
				expect(template).to notify("service[#{service_name}]").to(:restart)

				expect(chef_run).to enable_service(service_name)
				expect(chef_run).to start_service(service_name)
				service = chef_run.service(service_name)
				expect(service.provider).to equal(Chef::Provider::Service::Upstart)
			end

			it "creates a strider configuration file" do
				validate_config(CONFIG_PATH, "export STRIDER_CLONE_DEST=\"#{DATA_PATH}\"")
				file = chef_run.template(CONFIG_PATH)
				expect(file.owner).to eq(DEFAULT_USER)
				expect(file.group).to eq(DEFAULT_GROUP)
			end

			it "creates a log file" do
				expect(chef_run).to create_file_if_missing(LOG_FILE).with(
					owner: DEFAULT_USER,
					group: DEFAULT_GROUP
				)
			end

			it "creates a data directory" do
				expect(chef_run).to create_directory(DATA_PATH).with(
					owner: DEFAULT_USER,
					group: DEFAULT_GROUP
				)
			end

		end

		context "with a modified install directory" do

			let(:install_directory) { "/usr/share/strider" }

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version) do |node|
					node.set[:strider][:directory] = install_directory
				end.converge(described_recipe)
			end

			it "installs strider to the specified directory" do
				expect(chef_run).to create_directory(install_directory)
				expect(chef_run).to sync_git(install_directory).with(repository: STRIDER_REPOSITORY)
			end

			it "puts the strider configuration file in the install directory" do
				expect(chef_run).to render_file("#{install_directory}/#{CONFIG_FILE}")
			end

			it "puts the data directory in the install directory" do
				config_file = "#{install_directory}/#{CONFIG_FILE}"
				data_directory = "#{install_directory}/#{DATA_DIRECTORY}"
				expect(chef_run).to create_directory(data_directory)
				validate_config(config_file, "export STRIDER_CLONE_DEST=\"#{data_directory}\"")
			end

			it "modifies the service configuration" do
				validate_config(UPSTART_CONFIG, [
					"cd #{install_directory}",
					". #{install_directory}/#{CONFIG_FILE}"
				])
			end

		end

		context "with a modified log path" do

			let(:log_file) { "/var/log/strider/strider.log" }

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version) do |node|
					node.set[:strider][:log] = log_file
				end.converge(described_recipe)
			end

			it "configures strider with the specified log file" do
				create_log = "npm start >> #{log_file} 2>&1"
				expect(chef_run).to render_file(UPSTART_CONFIG).with_content(create_log)
			end

			it "creates the specified log file" do
				expect(chef_run).to create_file_if_missing(log_file)
			end

		end

		context "with a modified user and group" do

			let(:user) { "foo" }
			let(:group) { "bar" }

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version) do |node|
					node.set[:strider][:user] = user
					node.set[:strider][:group] = group
				end.converge(described_recipe)
			end

			it "creates the specified user and group" do
				expect(chef_run).to create_user(user)
				expect(chef_run).to create_group(group)

				expect(chef_run).to create_directory("/home/#{user}").with(
					owner: user,
					group: group
				)
			end

			it "applies the modified ownership to the install directory" do
				install_directory = chef_run.directory(INSTALL_DIRECTORY)
				expect(install_directory.owner).to eq(user)
				expect(install_directory.group).to eq(group)

				install_directory = chef_run.git(INSTALL_DIRECTORY)
				expect(install_directory.user).to eq(user)
				expect(install_directory.group).to eq(group)
			end

			it "applies the modified ownership to the configuration file" do
				config = chef_run.template(CONFIG_PATH)
				expect(config.owner).to eq(user)
				expect(config.group).to eq(group)
			end

			it "applies the modified ownership to the data directory" do
				directory = chef_run.directory(DATA_PATH)
				expect(directory.owner).to eq(user)
				expect(directory.group).to eq(group)
			end

			it "applies the modified ownership to the log file" do
				log = chef_run.file(LOG_FILE)
				expect(log.owner).to eq(user)
				expect(log.group).to eq(group)
			end

			it "runs the server as the specified user" do
				validate_config(UPSTART_CONFIG, "setuid #{user}")
			end

		end

		context "configured with a port" do

			let(:port) { 8080 }

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version) do |node|
					node.set[:strider][:port] = port
				end.converge(described_recipe)
			end

			it "adds the port value to the configuration file" do
				validate_config(CONFIG_PATH, "export PORT=#{port}")
			end

		end

		context "configured with a database URL" do

			let(:database_url) { "mongodb://example.com" }

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version) do |node|
					node.set[:strider][:database] = database_url
				end.converge(described_recipe)
			end

			it "adds the URL value to the configuration file" do
				validate_config(CONFIG_PATH, "export DB_URI=\"#{database_url}\"")
			end

		end

		context "configured with GitHub credentials" do

			let(:github_id) { "a_github_id" }
			let(:github_secret) { "a_github_secret" }

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version) do |node|
					node.set[:strider][:github][:client_id] = github_id
					node.set[:strider][:github][:client_secret] = github_secret
				end.converge(described_recipe)
			end

			it "adds the credentials to the configuration file" do
				validate_config(CONFIG_PATH, [
					"export PLUGIN_GITHUB_APP_ID=\"#{github_id}\"",
					"export PLUGIN_GITHUB_APP_SECRET=\"#{github_secret}\""
				])
			end

		end

		context "configured with Bitbucket credentials" do

			let(:bitbucket_id) { "a_bitbucket_id" }
			let(:bitbucket_secret) { "a_bitbucket_secret" }
			let(:bitbucket_host) { "example.com" }

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version) do |node|
					node.set[:strider][:bitbucket][:client_id] = bitbucket_id
					node.set[:strider][:bitbucket][:client_secret] = bitbucket_secret
					node.set[:strider][:bitbucket][:host] = bitbucket_host
				end.converge(described_recipe)
			end

			it "adds the credentials to the configuration file" do
				validate_config(CONFIG_PATH, [
					"export PLUGIN_BITBUCKET_APP_KEY=\"#{bitbucket_id}\"",
					"export PLUGIN_BITBUCKET_APP_SECRET=\"#{bitbucket_secret}\"",
					"export PLUGIN_BITBUCKET_HOSTNAME=\"#{bitbucket_host}\""
				])
			end

		end

		context "configured with a server URL" do

			let(:server_url) { "http://example.com" }

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version) do |node|
					node.set[:strider][:url] = server_url
				end.converge(described_recipe)
			end

			it "adds the URL value to the configuration file" do
				validate_config(CONFIG_PATH, "export SERVER_NAME=\"#{server_url}\"")
			end

		end

		context "configured with a data directory" do

			let(:data_directory) { "/home/strider" }

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version) do |node|
					node.set[:strider][:data] = data_directory
				end.converge(described_recipe)
			end

			it "creates the specified directory" do
				expect(chef_run).to create_directory(data_directory).with(
					owner: DEFAULT_USER,
					group: DEFAULT_GROUP
				)
			end

			it "adds the directory value to the configuration" do
				validate_config(CONFIG_PATH, "export STRIDER_CLONE_DEST=\"#{data_directory}\"")
			end

		end

		context "with a single plugin" do

			let(:plugin) { "https://github.com/example/plugin.git" }

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version) do |node|
					node.set[:strider][:plugins] = plugin
				end.converge(described_recipe)
			end

			it "installs the named plugin" do
				assert_plugin_installed plugin
			end

		end

		context "with a list of plugins" do

			let(:plugins) do
				[
					"https://github.com/foo/strider-foo.git",
					"git://github.com/bar/strider-bar.git"
				]
			end

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version) do |node|
					node.set[:strider][:plugins] = plugins
				end.converge(described_recipe)
			end

			it "installs the named plugins" do
				plugins.each { |plugin| assert_plugin_installed plugin }
			end

		end

		context "configured with an admin user" do

			let(:email) { "test@example.com" }
			let(:password) { "passw0rd" }

			let(:chef_run) do
				ChefSpec::Runner.new(platform: platform, version: version) do |node|
					node.set[:strider][:admin][:email] = email
					node.set[:strider][:admin][:password] = password
				end.converge(described_recipe)
			end

			it "creates an admin user account" do
				command = "node bin/strider addUser --email #{email} --password #{password} --admin"
				expect(chef_run).to run_execute(command).with(
					cwd: INSTALL_DIRECTORY,
					user: DEFAULT_USER,
					group: DEFAULT_GROUP
				)
			end

		end

	end

end

SITE_LOCKDOWN = Hash.new

@auth_credentials_file = File.join(RAILS_ROOT, 'config/site_lockdown_auth_credentials.yml')
if File.exists?(@auth_credentials_file)
  @auth_credentials = YAML.load(IO.read(@auth_credentials_file))
  SITE_LOCKDOWN[:username] = (@auth_credentials[:username] || @auth_credentials['username'])
  SITE_LOCKDOWN[:password] = (@auth_credentials[:password] || @auth_credentials['password'])
end

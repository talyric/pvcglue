#=======================================================================================================================
package 'web' do
#=======================================================================================================================
# rvm/ruby install based on http://ryanbigg.com/2010/12/ubuntu-ruby-rvm-rails-and-you/
  depends_on 'build-essential'
  depends_on 'git'
  depends_on 'rvm'
  depends_on 'no-rdoc'
  depends_on 'rvm-ruby-2.0'
  depends_on 'nginx'
  depends_on 'phusion-passenger'

  depends_on 'bundler'
  depends_on 'libpq-dev' # for pg gem
  #depends_on 'postgres'
  #depends_on 'libxml2'
  #depends_on 'libxslt'
  depends_on 'nodejs'
  depends_on 'imagemagick' # TODO:  app specific--will need to make system to include extra packages

  depends_on 'application-environment'
  depends_on 'application-web-server-config'

  apply do
    puts "*"*300
    trigger 'nginx:restart' # files are copied first using 'depends_on' then we restart.
  end

  validate do
    trigger('nginx:running')
    #RestClient.get(node.test_url).code == 200 rescue false
  end


end

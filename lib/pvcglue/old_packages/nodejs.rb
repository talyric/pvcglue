package 'nodejs' do
  depends_on 'apt'
  validate do
    trigger('apt:exists', 'nodejs') &&
        binary_exists?('node') &&
        binary_exists?('npm')
  end
  apply do
    trigger 'apt:ppa', 'ppa:chris-lea/node.js'
    trigger 'apt:update'
    trigger 'apt:install', 'nodejs'
  end
  remove do
    trigger 'apt:remove', 'nodejs'
  end
end


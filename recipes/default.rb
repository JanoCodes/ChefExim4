#
# Cookbook:: exim4
# Recipe:: default
#
# Copyright:: 2019, Andrew Ying.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

case node[:platform]
when 'ubuntu', 'debian'
    apt_update 'apt update' do
        action :update
    end
end

package 'exim4 dependencies' do
    case node[:platform]
    when 'ubuntu'
        case node['platform_version'].split('.')[0]
        when '16'
            package_name %w(libc6 libgdbm3 libldap-2.4-2 libpcre3 libssl1.0)
        when '18'
            package_name %w(libc6 libgdbm5 libldap-2.4-2 libpcre3 libssl1.1)
        end
    when 'debian'
        package_name %w(libc6 libgdbm3 libldap-2.4-2 libpcre3 libssl1.1)
    end
    action :install
end

package 'exim4 build dependencies' do
    case node[:platform]
    when 'ubuntu'
        package_name %w(build-essential gcc libc6-dev libgdbm-dev libjansson-dev libldap2-dev
            libmysqlclient-dev libpcre3-dev libssl-dev pkg-config)
    when 'debian'
        package_name %w(build-essential gcc libc6-dev libgdbm-dev libjansson-dev libldap2-dev
            default-libmysqlclient-dev libpcre3-dev libssl-dev pkg-config)
    end
    action :install
end

version = node['exim']['version']

remote_file "#{Chef::Config[:file_cache_path]}/exim-#{version}.tar.gz" do
    source  "#{node['exim']['url']}/exim-#{version}.tar.gz"
    mode    '0644'
end

group 'exim'

user 'exim' do
    gid     'exim'
    action  :create
end

directory '/usr/lib/exim' do
    owner 'exim'
    group 'exim'
    mode '0755'
    action :create
end

directory '/usr/lib/exim/lookups' do
    owner 'exim'
    group 'exim'
    mode '0755'
    action :create
end

bash 'exim4 build' do
    cwd Chef::Config[:file_cache_path]
    code <<-EOF
    tar -zxf exim-#{version}.tar.gz
    (cd exim-#{version} &&
        sed -e 's,^BIN_DIR.*$,BIN_DIRECTORY=/usr/sbin,'\
        -e 's,^CONF.*$,CONFIGURE_FILE=/etc/exim.conf,' \
        -e 's,^EXIM_USER.*$,EXIM_USER=exim,'           \
        -e 's,^HAVE_ICONV.*$,HAVE_ICONV=yes,'          \
        -e '/SUPPORT_TLS=yes/s,^# ,,'                  \
        -e '/USE_OPENSSL/s,^# ,,'                      \
        -e '/TLS_LIBS=-lssl -lcrypto/s,^# ,,'          \
        -e '/LOOKUP_MODULE_DIR=/s,^# ,,'               \
        -e 's,^# CFLAGS_DYNAMIC=-shared -rdynamic -fPIC$,CFLAGS_DYNAMIC=-shared -rdynamic -fPIC,'\
        -e 's,^# LOOKUP_JSON=.*$,LOOKUP_JSON=2,'       \
        -e 's,^# LOOKUP_LDAP=.*$,LOOKUP_LDAP=yes,'     \
        -e '/LDAP_LIB_TYPE=OPENLDAP2/s,^# ,,'          \
        -e 's,^# LOOKUP_MYSQL=.*$,LOOKUP_MYSQL=2,'     \
        -e 's,^EXIM_MONITOR,#EXIM_MONITOR,' src/EDITME > Local/Makefile &&
        printf "USE_GDBM=yes\nDBMLIB = -lgdbm\n" >> Local/Makefile &&
        printf "LOOKUP_INCLUDE=-I /usr/include/ldap -I /usr/include/mysql\n" >> Local/Makefile &&
        printf "LOOKUP_LIBS=-L/usr/lib -lldap -llber -lmysqlclient -ljansson\n" >> Local/Makefile &&
        printf "EXTRALIBS=-export-dynamic -rdynamic -ldl\n" >> Local/Makefile)
    (cd exim-#{version} &&
        make &&
        make install)
    EOF
end

package 'exim4 build dependencies' do
    action :remove
end

directory "#{Chef::Config[:file_cache_path]}/exim-#{version}" do
    recursive true
    action :delete
end

remote_file "#{Chef::Config[:file_cache_path]}/exim-#{version}.tar.gz" do
    action :delete
end
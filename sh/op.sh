#!/bin/bash


function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../
  cd .. && rm -rf $repodir
}

echo 'src-git xd https://github.com/shiyu1314/openwrt-packages' >>feeds.conf.default


git_sparse_clone "$REPO_BRANCH" https://github.com/immortalwrt/luci modules/luci-base
git_sparse_clone "$REPO_BRANCH" https://github.com/immortalwrt/luci modules/luci-mod-status

git clone -b main --depth 1 --single-branch https://github.com/shiyu1314/luci-theme-material3 package/luci-theme-material3
# luci-theme-material3
rm -rf package/luci-theme-material3/{.git,Readme.md}



./scripts/feeds update -a
curl -sSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh -o add_turboacc.sh && bash add_turboacc.sh

rm -rf feeds/luci/modules/luci-base
rm -rf feeds/luci/modules/luci-mod-status
cp -rf luci-base feeds/luci/modules
cp -rf luci-mod-status feeds/luci/modules/

pushd feeds/luci
    patch -p1 < 0001-luci-mod-system-add-modal-overlay-dialog-to-reboot.patch
    patch -p1 < 0002-luci-mod-status-displays-actual-process-memory-usage.patch
    patch -p1 < 0003-luci-mod-status-storage-index-applicable-only-to-val.patch
    patch -p1 < 0004-luci-mod-status-firewall-disable-legacy-firewall-rul.patch
    patch -p1 < 0005-luci-mod-system-add-refresh-interval-setting.patch
    patch -p1 < 0006-luci-mod-system-mounts-add-docker-directory-mount-po.patch
    patch -p1 < 0001-luci-mod-network-add-option-for-ipv6-max-plt-vlt.patch
popd


sed -i 's/+uhttpd /+luci-nginx /g' feeds/luci/collections/luci/Makefile
sed -i 's/+uhttpd-mod-ubus //' feeds/luci/collections/luci/Makefile
sed -i 's/+uhttpd /+luci-nginx /g' feeds/luci/collections/luci-light/Makefile
sed -i "s/+luci /+luci-nginx /g" feeds/luci/collections/luci-ssl-openssl/Makefile
sed -i "s/+luci /+luci-nginx /g" feeds/luci/collections/luci-ssl/Makefile
sed -i 's/+uhttpd +uhttpd-mod-ubus /+luci-nginx /g' feeds/packages/net/wg-installer/Makefile
sed -i '/uhttpd-mod-ubus/d' feeds/luci/collections/luci-light/Makefile
sed -i 's/+luci-nginx \\$/+luci-nginx/' feeds/luci/collections/luci-light/Makefile

# nginx-util - fix gcc13
if [ "$REPO_BRANCH" = "openwrt-23.05" ]; then
    pushd feeds/packages
        patch -p1 < 0001-nginx-util-fix-compilation-with-GCC13.patch
        patch -p1 < 0002-nginx-util-move-to-pcre2.patch
    popd
fi


# nginx - latest version
rm -rf feeds/packages/net/nginx
git clone https://github.com/sbwml/feeds_packages_net_nginx feeds/packages/net/nginx -b "$REPO_BRANCH"
sed -i 's/procd_set_param stdout 1/procd_set_param stdout 0/g;s/procd_set_param stderr 1/procd_set_param stderr 0/g' feeds/packages/net/nginx/files/nginx.init

# nginx - ubus
sed -i 's/ubus_parallel_req 2/ubus_parallel_req 6/g' feeds/packages/net/nginx/files-luci-support/60_nginx-luci-support
sed -i '/ubus_parallel_req/a\        ubus_script_timeout 300;' feeds/packages/net/nginx/files-luci-support/60_nginx-luci-support

# uwsgi - fix timeout
sed -i '$a cgi-timeout = 600' feeds/packages/net/uwsgi/files-luci-support/luci-*.ini
sed -i '/limit-as/c\limit-as = 5000' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
# disable error log
sed -i "s/procd_set_param stderr 1/procd_set_param stderr 0/g" feeds/packages/net/uwsgi/files/uwsgi.init

# uwsgi - performance
sed -i 's/threads = 1/threads = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's/processes = 3/processes = 4/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's/cheaper = 1/cheaper = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini

# rpcd - fix timeout
sed -i 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config
sed -i 's#20) \* 1000#60) \* 1000#g' feeds/luci/modules/luci-base/htdocs/luci-static/resources/rpc.js



# openssl urandom
sed -i "/-openwrt/iOPENSSL_OPTIONS += enable-ktls '-DDEVRANDOM=\"\\\\\"/dev/urandom\\\\\"\"\'\n" package/libs/openssl/Makefile



# tcp-brutal
git clone https://github.com/sbwml/package_kernel_tcp-brutal package/kernel/tcp-brutal




./scripts/feeds update -a
./scripts/feeds install -a

sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

sed -i "s/192.168.1.1/$OP_IP/" package/base-files/files/bin/config_generate

sed -i "s/hostname='.*'/hostname='$name'/g" ./package/base-files/files/bin/config_generate

sudo rm -rf package/base-files/files/etc/banner

sed -i "s/%D %V %C/%D %V $(TZ=UTC-8 date +%Y.%m.%d)/" package/base-files/files/etc/openwrt_release

sed -i "s/%R/by $OP_author/" package/base-files/files/etc/openwrt_release

date=$(date +"%Y-%m-%d")
echo "                                                    " >> package/base-files/files/etc/banner
echo "  _______                     ________        __" >> package/base-files/files/etc/banner
echo " |       |.-----.-----.-----.|  |  |  |.----.|  |_" >> package/base-files/files/etc/banner
echo " |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|" >> package/base-files/files/etc/banner
echo " |_______||   __|_____|__|__||________||__|  |____|" >> package/base-files/files/etc/banner
echo "          |__|" >> package/base-files/files/etc/banner
echo " -----------------------------------------------------" >> package/base-files/files/etc/banner
echo "         %D ${date} by $OP_author                     " >> package/base-files/files/etc/banner
echo " -----------------------------------------------------" >> package/base-files/files/etc/banner

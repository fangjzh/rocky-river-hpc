### find the centos related perl module files ###
# find /opt/xcat/ -name *.pm -exec echo {} \; -exec grep -n centos  {} \;  > tmp.txt
## moldify them (add rocky paragraph after centos)

## find centos related config files ##
# find /opt/xcat/ -name *centos* 
## copy them to the relative rocky folder


### mkdir ./backup_xcat_hack
### cd ./backup_xcat_hack
### 
### cp -r /opt/xcat/share/xcat/install/rocky install
### cp -r /opt/xcat/share/xcat/netboot/rocky netboot
### 
### cp /opt/xcat/lib/perl/xCAT/data/discinfo.pm ./discinfo.pm
### cp /opt/xcat/lib/perl/xCAT_plugin/imgcapture.pm ./imgcapture.pm
### cp /opt/xcat/lib/perl/xCAT_plugin/imgport.pm ./imgport.pm
### 
### cp /opt/xcat/lib/perl/xCAT_plugin/anaconda.pm ./anaconda.pm 
### cp /opt/xcat/lib/perl/xCAT_plugin/geninitrd.pm ./geninitrd.pm 
### 
### cp /opt/xcat/lib/perl/xCAT_plugin/route.pm ./route.pm
### cp /opt/xcat/lib/perl/xCAT/Postage.pm ./Postage.pm
### cp /opt/xcat/lib/perl/xCAT/Utils.pm ./Utils.pm 
### cp /opt/xcat/lib/perl/xCAT/ProfiledNodeUtils.pm ./ProfiledNodeUtils.pm 
### cp /opt/xcat/lib/perl/xCAT/SvrUtils.pm ./SvrUtils.pm 
### cp /opt/xcat/lib/perl/xCAT/Template.pm ./Template.pm 
### cp /opt/xcat/lib/perl/xCAT/Schema.pm ./Schema.pm 

###########################
cp -r install /opt/xcat/share/xcat/install/rocky 
cp -r netboot /opt/xcat/share/xcat/netboot/rocky 
cp ./discinfo.pm /opt/xcat/lib/perl/xCAT/data/discinfo.pm 
cp ./imgcapture.pm /opt/xcat/lib/perl/xCAT_plugin/imgcapture.pm 
cp ./imgport.pm /opt/xcat/lib/perl/xCAT_plugin/imgport.pm 
cp ./anaconda.pm /opt/xcat/lib/perl/xCAT_plugin/anaconda.pm 
cp ./geninitrd.pm /opt/xcat/lib/perl/xCAT_plugin/geninitrd.pm 
cp ./route.pm /opt/xcat/lib/perl/xCAT_plugin/route.pm 
cp ./Postage.pm /opt/xcat/lib/perl/xCAT/Postage.pm 
cp ./Utils.pm /opt/xcat/lib/perl/xCAT/Utils.pm 
cp ./ProfiledNodeUtils.pm /opt/xcat/lib/perl/xCAT/ProfiledNodeUtils.pm 
cp ./SvrUtils.pm /opt/xcat/lib/perl/xCAT/SvrUtils.pm 
cp ./Template.pm /opt/xcat/lib/perl/xCAT/Template.pm 
cp ./Schema.pm /opt/xcat/lib/perl/xCAT/Schema.pm 



{ config, pkgs, ... }:

{
  fileSystems."/srv/diska/main/videos" =
    { device = "/srv/diskb/videos";
	  options = ["bind"];
    };
  fileSystems."/srv/diska/main/books" =
    { device = "/srv/diskb/books";
	  options = ["bind"];
    };
  fileSystems."/srv/diska/main/music" =
    { device = "/srv/diskb/music";
	  options = ["bind"];
    };
  fileSystems."/srv/diska/main/pictures" =
    { device = "/srv/diskb/pictures";
	  options = ["bind"];
    };
  fileSystems."/srv/diska/main/downloads" =
    { device = "/srv/diskb/downloads";
	  options = ["bind"];
    };
}


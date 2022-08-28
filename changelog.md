
# Change Log
All notable changes to this project will be documented in this file.
It's the Change Log for https://github.com/dapuru/zfsbackup

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).
 
## [0.7] - 2022-08-26
 
### Added
 
### Changed

Added Linux compatibility, marked in the code with #!!
This is due to the parallel use of a local Linux system, and there are some things different between Linux and FreeBSD, namely:

- reverse order "tail -r" vs. "tac"
- Array handling in zsh.
  This is a deal breaker for usage in TrueNAS scale. 
  Currently can't set parameter KSH_ARRAYS https://zsh.sourceforge.io/Doc/Release/Options.html#Shell-Emulation
- "date -j -f" replacement for Linux

### Fixed
 
## [0.6.1] - 2022-04-03

Earlier change is not documented seriously...

### Added

- new Parameter -y: don't ask when creating/overwriting folders in backup
 
### Changed
  
- Support for encrypted Backup-Pool using load-key
- Scrub for Backup-Pool
- Email-Notification
- Cleansing
- .env-file for config
- Regex for Scrub-Date & Command line parameter for Dry-run (-d) and forced scrub (-f)
 
### Fixed
 
- several stuff
 
## [0.6] - 2021-06-05
 
Initial public release
 
### Added
   
### Changed
 
### Fixed
 





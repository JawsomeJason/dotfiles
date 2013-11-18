dotfiles
========

## My Personal Machine Setup

From: http://net.tutsplus.com/tutorials/tools-and-tips/setting-up-a-mac-dev-machine-from-zero-to-hero-with-dotfiles/

**Before running anything**, put anything you want to keep from .bash_profile or .gitconfig (like user info) into ~/.extras (like .

Then, run the following:

	# homebrew, rvm, etc
	bash install-deps.sh

	# copies dotfiles to ~
	bash bootstrap.sh

	cd ~/

	# installs CLI stuff
	bash .brew

	# installs common apps
	bash .cask

	# sets default OSX settings (requires restart)
	bash .osx

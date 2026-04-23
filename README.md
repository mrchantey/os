# OS

My [Omarchy](https://omarchy.org/) config.

## Quickstart

```sh
# pull this repo into `~/me/os`, cd into it and install just
mkdir ~/me && cd ~/me && git clone https://github.com/mrchantey/os.git && cd os && sudo pacman -S --noconfirm just
# log into github
gh auth login
# run
just init
```

# Additional Steps

Haven't yet found a way to automate these, to be executed post install.

1. Auth:
```

```
2. Background
	- `GO > Style > Background > Everforest`
	- `SUPER + CTRL + SPACE`
3. Bluetooth Mouse
4. Chrome notifications
	- `chrome://settings/content/notifications`
	- `Don't allow sites to send notifications`
1. AWS
	- `aws configure`
	- Create a new user or revoke and reissue access key 
	- `https://us-east-1.console.aws.amazon.com/iam/home?region=us-west-2#/users`
	- `Security Credentials > Access Keys > Create Access Key`
		- Command Line Interface (CLI)
		- Description Tag: None
	- `Access Key Id: ^`
	- `Access Key Secret Key: ^`
	- `Default region name: us-west-2`
	- `Default output format: None`


## Optional Steps

- Nvidia for gaming `just install-nvidia-deps`
- Ollama `just install-ollama`

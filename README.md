# GitFetcher
A Godot addon that lets you download files from public GitHub repos into your Godot project in the editor.

Perfect when you reuse old files from past projects, you can just download them into your current Godot project without leaving Godot

# How To Format?
In the Owner section, write the repo's owner, for example, "SnapGamesStudio
In the Repo, write the repo's name, for example, "Gallery"
In the last section, it's already filled out with "main"; this is the branch of the repo you are going to download

![Gitfetcher example 1](https://github.com/user-attachments/assets/e56dce48-2c41-42ba-b0ff-4c0c4da62dd4)

Or paste the URL for the GitHub repo 

<img width="700" height="149" alt="image" src="https://github.com/user-attachments/assets/e8540afe-4aad-41ab-a1fa-4030745c6134" />


# How to access "Private Repos"

<ins> **Step 1:** Create a GitHub Token </ins>

1. Go to GitHub.com
2. Click your profile picture → Settings
3. Open Developer settings
4. Click Personal access tokens
   - Choose Fine-grained tokens (recommended)
   - Or Tokens (classic)
  
<ins> **Step 2:** Configure Token Permissions </ins>

Fine-grained token (recommended)

   - Repository access → Only select repositories (or all)
   - Permissions:

      - Contents → Read-only

Classic token

   - Enable:
      ☑ repo

<ins> **Step 3:** Copy the Token </ins>

- Click Generate token

- Copy it immediately
   ⚠ GitHub will not show it again

<ins> **Step 4:** Paste the Token into the Addon </ins>

- Open your project in Godot

- Enable the addon (if not already enabled)

- Open the addon dock

- Paste the token into the GitHub Token field

- The token is saved automatically in Editor Settings (Local)
     
# How To Use?

1. Download the latest release build. 
<img width="197" height="105" alt="image" src="https://github.com/user-attachments/assets/005bfeef-52cc-4bd9-a6e9-3cdc8b7cfca4" />

2. In Godot, install the zip file you just downloaded
   
<img width="749" height="541" alt="image" src="https://github.com/user-attachments/assets/2164b504-0ef2-4e26-816d-d785b654c2ca" />

4. Make sure when installing, you have Ignore Asset Root
   
   <img width="743" height="670" alt="image" src="https://github.com/user-attachments/assets/2de8e810-032b-4b33-b958-e30ae638933d" />

5. Now head to the Project Settings and in the Plugin Tab, enable the addon
   <img width="1201" height="301" alt="image" src="https://github.com/user-attachments/assets/d9b6dc6f-e78b-4199-a6c1-c2fb2156ad4a" />
   
6. Now you will notice a new editor tab on the right, click on GitFetcher
   
   <img width="521" height="143" alt="image" src="https://github.com/user-attachments/assets/6cc25e0b-3701-4558-8bd8-3cf9eb22c531" />

7. now you can access "PUBLIC" GitHub repos

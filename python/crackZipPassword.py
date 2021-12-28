import zipfile

def crackZip(wordlist, file):
  with open(wordlist, 'rb') as wordlist:
    for password in wordlist:
      try:
        zipfile.ZipFile(file).extractall(pwd=password.strip())
      except:
        continue
      else:
        print('---------------------------------')
        print('Password found! \"' + password.decode().strip() + '\"')
        print('---------------------------------')
        break
crackZip('rockyou.txt', 'crackThis.zip')

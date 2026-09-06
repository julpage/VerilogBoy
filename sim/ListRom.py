import os


romList = []

# for eachFolder in os.walk("./cinema"):
for eachFolder in os.walk(".\cinema\mts-20260714-0944-31510e1"):
    for eachFile in eachFolder[2]:
        if eachFile.lower().endswith((".gb", ".gbc")):
            filePath = os.path.join(eachFolder[0], eachFile)
            filePath = filePath.replace("\\", "/")
            print(filePath)

            romList.append(filePath)

romList = sorted(romList)
with open("Test_ROMS.txt", 'w') as f:
    for i in romList:
        f.write(
            f'"{i}",\n'
        )

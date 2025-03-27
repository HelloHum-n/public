Restrict User1 from accessing App1 from non trust network unless they have a managed device

CA 1 - Trusted network

Target user: User1
Target Resource: App1
Network: Exclude Trusted Network
Grant: Hybrid joined or Compliance

CA 2 - MFA

Target user: User1
Target Resource: App filtering ( Custom security attribute)
GRANT: MFA



Scenerio 1
user in trusted network - CA1 wont applied , CA2 applied-> doesnt require managed device
user needs MFA

Scenerio 2
User not in trust network (Alan's home) - > CA1 and CA2 applied -> managed device
user needs MFA
class_name Email
extends Resource
## One email on a customer's computer.

## Exchange shows TRASH as Deleted Items and SENT as Sent Items.
enum Folder { INBOX, SENT, TRASH, OUTBOX }

@export var folder: Folder = Folder.INBOX
@export var from: String = ""
@export var to: String = ""
@export var subject: String = ""
## When it was sent, as "1996-05-28 21:14". Exchange shows it as Received in the list and as Sent
## in the message.
@export var sent: String = ""
@export_multiline var body: String = ""
## Unread emails show in bold, with a closed envelope.
@export var read: bool = false


## The sender's name without the address: "Kent" for "Kent <kent@modemlandia.se>".
func sender_name() -> String:
	var at := from.find(" <")
	return from.left(at) if at > 0 else from

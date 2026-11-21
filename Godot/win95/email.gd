class_name Email
extends Resource
## One email on a customer's computer.

enum Folder { INBOX, SENT, TRASH }

@export var folder: Folder = Folder.INBOX
@export var from: String = ""
@export var to: String = ""
@export var subject: String = ""
@export_multiline var body: String = ""
## Unread emails show in bold in the inbox.
@export var read: bool = false

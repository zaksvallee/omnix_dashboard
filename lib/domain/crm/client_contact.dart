class ClientContact {
  final String contactId;
  final String channel; // email, phone, whatsapp, in_person
  final String summary;
  final String loggedAt;

  const ClientContact({
    required this.contactId,
    required this.channel,
    required this.summary,
    required this.loggedAt,
  });
}

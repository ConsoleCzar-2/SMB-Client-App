import 'package:smb_app/models/smb_item.dart';
import 'package:smb_connect/smb_connect.dart';
// For SMB protocol calls and file handling


// SMB operationos controller class
class SmbService {
  final String host;      // IP of host
  final String share;     // Shared folder
  final String username;  // SMB login username
  final String password;  // SMB password

  late final SmbConnect connection; // Session variable, will only be initialized once when connection is made
  // Constructor
  SmbService({
    required this.host,
    required this.share,
    required this.username,
    required this.password,    
  });

  // Initializing SMB session, init() must be called on SmbService object before use
  Future<void> init() async {
    connection = await SmbConnect.connectAuth(
      host: host, 
      username: username, 
      password: password, 
      domain: "",
    );
  }

  // Func for listing all shared folder on host
  Future<List<SmbItem>> listShares() async {
    try{
      final shares = await connection.listShares(); // lists shared folders
      
      return shares.map((share) => SmbItem (
        name: share.name,
        isDirectory: true
      )).toList();
    }
    catch (e) {
      throw Exception("SMB Error: ${e.toString()}");
    }
    
  }

  // Closing the SMB session
  Future<void> disconnect() async {
    await connection.close();
  }


  // Listing out all the files/folders at the mentioned path ("/" by default)
  Future<List<SmbItem>> listDirectory(String path) async {
  // Future is used for asynchronous computation, so the function 
  // will return after the network opoeratioon is finished

    try {
      // Creates an SMB connection with the given params
      final folder = await connection.file(path);  // returns folder data
      final files = await connection.listFiles(folder);  // returns file data

      // Return after converting raw SMB data to SmbItem object
      return files.map((file) => SmbItem (
        name: file.name,
        isDirectory: file.isDirectory(),
      )).toList();
    }
    catch (e) {
      throw Exception("SMB Error: ${e.toString()}");
    }
  }

}


/* Sample usage

final smb = SmbService(...);
await smb.init(); //REQUIRED
final files = await smb.listDirectory("/");

*/

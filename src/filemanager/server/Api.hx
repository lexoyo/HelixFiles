package filemanager.server;
import filemanager.cross.FileVO;
import filemanager.cross.FolderVO;
import filemanager.cross.FileUpdatedVO;
import haxe.Log;
import php.FileSystem;
import php.io.File;

/**
 * ...
 * @author valerie.elimak - blog.elimak.com
 */

typedef FileHelper = {
	var extension	: String;
	var filename	: String;
	var path		: String;
}

class Api {
	
	private var _explorer 	: FileExplorer;
	private static inline var FILES_FOLDER : String = "../files";
	
	public function new() {
		_explorer = new FileExplorer();
	}
	
	public function getTreeFolder ( folderpath : String) : Null<FolderVO> {
		return _explorer.getFolders(folderpath);
	}	
	
	public function getFiles ( folderpath : String) : Null<Array<FileVO>> {
		return _explorer.getFiles(folderpath);
	}
	
	public function backupAsTemporary ( filepath : String ) : FileUpdatedVO {
		var response	: FileUpdatedVO = new FileUpdatedVO();
		response.filepath = filepath;
		
		var file		: FileHelper = getFileHelper (filepath);
		var oldFile 	: String = file.path +"/"+ file.filename + "." + file.extension;
		var tempFile 	: String = file.path +"/"+ file.filename + "_temp." + file.extension;
		
		if ( FileSystem.exists(oldFile) ){
			FileSystem.rename(oldFile, tempFile);
			response.success = FileSystem.exists(tempFile);
			if ( !response.success )
				response.error = "failed to back up " + oldFile;
		}
		else{
			response.success = true; 
		}
		return response;
	}
	
	public function deleteTempFile ( filepath : String ) : FileUpdatedVO {
		var response	: FileUpdatedVO = new FileUpdatedVO();
		var file		: FileHelper = getFileHelper (filepath);
		var tempFile 	: String = file.path +"/"+ file.filename + "_temp." + file.extension;
		response.filepath = filepath;
		
		if ( FileSystem.exists(tempFile) ){
			FileSystem.deleteFile(tempFile);
			response.success = !FileSystem.exists(tempFile);
		}
		else {
			response.success = true;
		}
		if ( !response.success ) response.error = "the file could not be deleted";
	
		return response;
	}	
	
	private function unlink( path : String ) : Void { 
		if( FileSystem.exists( path ) )  { 
			if( FileSystem.isDirectory( path ) ) { 
				for( entry in FileSystem.readDirectory( path ) ) { 
					unlink( path + "/" + entry ); 
				} 
				FileSystem.deleteDirectory( path ); 
			} 
			else { 
				FileSystem.deleteFile( path ); 
			} 
		} 
	} 
	
	public function deleteFile ( filepath : String ) : FolderVO {
		var validFolder = validatePath(filepath);
		
		unlink(filepath);

		var response	: FolderVO = getTreeFolder(FILES_FOLDER);
		return response;
	}	
	
	public function createFolder ( folderpath : String ) : FolderVO {
		var validFolder = validatePath(folderpath);
		FileSystem.createDirectory(validFolder);
		var response	: FolderVO = getTreeFolder(FILES_FOLDER);
		return response;
	}
	
	private function moveFileToFolder (filePath: String, fileName: String, folderPath: String ) : Bool {
		if ( filePath == (folderPath + "/" + fileName) ) return true;
		var newPath = validatePath(folderPath + "/" + fileName);
		File.copy(filePath, newPath);
		if ( FileSystem.exists(folderPath + "/" + fileName)){
			FileSystem.deleteFile(filePath);
			return true;
		}
		return false;
	}
	
	private function validatePath(filePath:String) : String {
		if ( FileSystem.exists(filePath)) {
			for (i in 1...100) {
				if ( !FileSystem.exists(filePath + "(" + i + ")") ) {
					return filePath + "(" + i + ")";
				}
			}
		}
		return filePath;
	}
	
	private function getFileHelper(filepath:String) : FileHelper {
		var result 		: FileHelper = {extension: "", filename: "", path:""};
		var splitted 	: Array<String> = filepath.split(".");
		result.extension  = splitted.pop();
		splitted = splitted.join(".").split("/");
		result.filename  = splitted.pop();
		result.path  = splitted.join("/");

		return result;
	}
}
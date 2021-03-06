package filemanager.client.models;
import filemanager.client.services.Api;
import filemanager.cross.FileVO;
import filemanager.cross.FolderVO;
import filemanager.cross.FileUpdatedVO;
import haxe.Json;
import haxe.Log;
import js.Dom;
import js.Lib;
import js.Worker;

/**
 * ...
 * @author valerie.elimak - blog.elimak.com
 */

typedef FileToUpload = {
	var file				: Dynamic;
	var validateFileName	: Dynamic;

	var started			: Bool;
	var initialized		: Bool;
	var progressPercent	: Float;
	var completed		: Bool;
}

typedef UploadProgress = {
	var result 		: Dynamic<{filename: String,filesize: Int, percentuploaded: Float, chunksize: Float}>;
	var type		: String;
	var destination	: String;
}

typedef UploadComplete = {
	var result 		: Dynamic<{filename: String,filesize: Int}>;
	var type		: String;
	var destination	: String;
}

typedef UploadStarted = {
	var result 		: Dynamic<{filename: String}>;
	var type		: String;
	var destination	: String;
}

typedef UploadError = {
	var error: String;
}
 
class FilesModel 
{
	private var _api : Api;
	private var _uploadsQueue 	: Hash<FileToUpload>;
	public var onUploadUpdate 	: FileToUpload->Void;
	
	private var _selectedFolderPath : String;
	public var selectedFolder(get_selectedFolder, set_selectedFolder):String;
	
	public var appDispatcher(get_appDispatcher, null):HtmlDom;
	public var selectedFile(get_selectedFile, null):FileVO;
	
	private var _selectedFile 	 : FileVO;
	private var _targetFolder	 : FolderVO;
	
	private var _appDispatcher	 : HtmlDom; // used as a dispatch
	
	public static inline var PATH_UPDTATE : String = "pathUpdate";
	
/**
 * we pass the rootElement of FileManager to the model in order to dispatch event (only HtmlDom can dispatch)
 * @param	appRootElement
 */
	public function new( appRootElement : HtmlDom ) {
		_api = new Api();
		_appDispatcher = appRootElement;
		_uploadsQueue = new Hash<FileToUpload>();
	}
	
// ------------------------ // 
// DEFAULT ERROR HANDLERS
// ------------------------ //
/**
 * Default errors handler with the remoting calls - all failures with the Api.hx will be routed here
 * @param	e
 */
	private function handleError( e: Dynamic) {
		Log.trace("FilesModel - handleError() ERROR: Line "+ e.lineno + " in " + e.filename + ": " + e.message);
	}
		
// ------------------------ // 
// READ FOLDERS + FILES
// ------------------------ //

// PUBLIC

/**
 * here the Model is only bridging the access to the server Api to read the files and the Folders
 * @param	folderpath
 * @param	onSuccess
 */
	public function getTreeFolder ( folderpath : String, onSuccess: FolderVO->Void ) : Void {
		_api.getTreeFolder(folderpath, onSuccess);
	}
	
	public function getFiles ( folderpath: String, onSuccess: Array<FileVO>->Void ) : Void {
		_api.getFiles(folderpath, onSuccess);
	}
	
	public function browseFiles( evt: MouseEvent) : Void {
	}
	
// ------------------------ // 
// UPLOAD
// ------------------------ //

// PUBLIC

/**
 * We list all the files that were dropped for upload and we start their initialisation.
 * to avoid overriding old files, before we are sure that the new file is completely uploaded, we rename them on 'oldName_temp' file
 * @param	files
 */
	public function uploadSelectedFiles ( files: Array<Dynamic> ) : Void {
		
		for ( file in files ) {
			var backupFileFullPath = _selectedFolderPath + validateFileName(file.name);
			var fileToUpload : FileToUpload = { file : file, validateFileName:validateFileName(file.name), initialized : false, progressPercent : 0, completed : false, started: false };
			_uploadsQueue.set(backupFileFullPath, fileToUpload);
		}
		for (key in _uploadsQueue.keys()) {
			var filehelper : FileToUpload = cast _uploadsQueue.get(key);
			if ( !filehelper.initialized ) {
				_api.backupAsTemporary(key, handleUploadInitialized);
				_uploadsQueue.get(key).initialized = true;
				onUploadUpdate(_uploadsQueue.get(key));
			}
		}
	}
	
// PRIVATE

/**
 * Handle the initialization: 
 * The initialization consists on backing up a previous version of the file
 * (if there is one existing) before the upload of the new file.
 * So if the transfer fails, we wont override the initial file.
 * The upload starts right after the completion of this step.
 * @param	response
 */
	private function handleUploadInitialized(response: FileUpdatedVO): Void {
		if ( response.error != null && response.error != "" ) {
			Log.trace("FilesModel - handleUploadInitialized() - ERROR:  "+response.error);
		}
		
		if( _uploadsQueue.exists(response.filepath)) {
			var uploadWorker = new Worker('fileupload.js');
			uploadWorker.onmessage = handleUploadProgress;
			uploadWorker.onerror = handleError;
			var dataMsg = { file: _uploadsQueue.get(response.filepath).file,
							validName:  validateFileName(_uploadsQueue.get(response.filepath).file.name),
							destination: _selectedFolderPath
							};
			uploadWorker.postMessage(dataMsg);
		}
	}
	
/**
 * The result received is of type JSON
 * we parse them againt the typedef declared above the class
 * @param	msg
 */
	private function handleUploadProgress( msg: Dynamic ) : Void {
		
		var response: Dynamic = Json.parse(msg.data);
		var filePath : String = response.destination + response.result.filename;
		var fileToUpload : FileToUpload = _uploadsQueue.get(filePath);
		
		switch (response.type) {
			case "progress"	: 
				fileToUpload.progressPercent = response.result.percentuploaded;
				onUploadUpdate(fileToUpload);
				
			case "completed": 
				var tempFile : String = response.destination + response.result.filename;
				_api.deleteTempFile(tempFile, function( file: FileUpdatedVO ) {
									onUploadUpdate (fileToUpload);
								});
				fileToUpload.completed = true;
				onUploadUpdate(fileToUpload);
				_uploadsQueue.remove(filePath);
				
			case "started"	: 
				fileToUpload.started = true;
				onUploadUpdate(fileToUpload);
				
			case "error"	: 
				Log.trace("FilesModel - handleUploadProgress() - response: error "+response.error);
		}
	}	
	
	private function validateFileName ( filename: String ) : String {
		// TODO: to complete if needed
		filename = StringTools.replace(filename, " ", "");
		filename = StringTools.replace(filename, "$", "");
		filename = StringTools.replace(filename, "+", "");
		return filename;
	}
	
// ------------------------ // 
// FILE MANAGEMENT
// ------------------------ //

// PUBLIC

	// clicking button delete when folder or file is selected -> actually move the files into the garbage
	// Todo: keep track of the initial path is we need to restaure the file or folder
	public function deleteFile ( filePath: String, onSuccess: FolderVO->Void ) {
		_api.deleteFile( filePath, onSuccess);
	}
	
	// using drag and drop
	public function moveFile ( filePath: String, newPath: String ) { }
	
	// keep data for pasting later
	public function copyFile ( filePath: String ) { }
	
	// only available when a file was first copied
	public function pasteFile ( newPath: String ) { }
	
/**
 * TODO: This is supposed to open a dialog window, but it doesnt seem to work for image files (I did not test on other type of file)
 * @param	filePath
 */
	public function download( filePath: String ) {
		var correctedPath = ( filePath.split("../").length > 0 ) ?  filePath.split("../")[1] : filePath;
		js.Lib.window.open(correctedPath,'Downloading');  
	}
	
	public function renameFile ( filePath: String, newName: String, onSuccess: FolderVO->Void ) {
		_api.renameFile( filePath, newName, onSuccess);
	}
	
	public function createNewFolder ( folderPath : String, onSuccess: FolderVO->Void ) {
		_api.createFolder( folderPath, onSuccess);
	}
	
// ------------------------ // 
// UPLOAD MANAGEMENT
// ------------------------ //

	public function onCancelUpload ( trackID: String ) : Void {
		// find the ref in the queue and remove it
		// find the worker and stop it?
		// restaure the temp file if there is one
		// update the uis when the upload was cancelled
		Log.trace("FilesModel - onCancelUpload() "+trackID);
	}
	
// ------------------------ // 
// GETTER / SETTER
// ------------------------ //

	private function get_selectedFolder():String {
		return _selectedFolderPath;
	}
	
	private function set_selectedFolder(value:String):String {
		var lastCharacter = value.substr(value.length - 1, 1);
		_selectedFile = null;
		_selectedFolderPath = value;
		if (lastCharacter != "/") {
			_selectedFolderPath += "/";
		}
		dispatchUpdate();
		return _selectedFolderPath;
	}
	
	private function get_selectedFile():FileVO {
		return _selectedFile;
	}
	
	private function get_appDispatcher():HtmlDom {
		return _appDispatcher;
	}
	
// ------------------------------------------------------ // 
// CUSTOM DISPATCH (file/folder selected is updated)
// ------------------------------------------------------ //

	private function dispatchUpdate() {
		var event : CustomEvent = cast Lib.document.createEvent("CustomEvent");
		event.initCustomEvent(PATH_UPDTATE, false, false, _appDispatcher);
		_appDispatcher.dispatchEvent(event);
	}	
	
// ------------------------------------------------- // 
// DRAG & DROP of FILES -> Move to new Folder path
// ------------------------------------------------- //

	public function setDraggedFile( file: FileVO ) {
		_selectedFile = file;
		dispatchUpdate();
	}

	public function setFolderOfDroppedFile( folder:FolderVO, onUpdateFoldersStates: FolderVO->Void ) {
		_targetFolder = folder;
		// reload the list of folder after a file was dropped
		var result = _api.moveFileToFolder(_selectedFile.path, _selectedFile.name, _targetFolder.path,
															function( sucess: Bool ) : Void {
																getTreeFolder("../files", onUpdateFoldersStates);
															});
	}
}
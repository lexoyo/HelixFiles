package filemanager.client.views.base;
import haxe.Log;
import js.Dom;
import org.slplayer.component.ui.DisplayObject;

/**
 * ...
 * @author valerie.elimak - blog.elimak.com
 */

class View extends DisplayObject {

	public function new(rootElement:HtmlDom, SLPId:String){
		super(rootElement, SLPId);
	}
	
/**
 * Remove all the children - clean disposing
 */
	private function clear() {
		
		var childNodes = rootElement.childNodes.length;
		while (rootElement.hasChildNodes()) {
			var child: HtmlDom = rootElement.childNodes[0];
			rootElement.removeChild(child);
		}
	}
}
package filemanager.client.views.uis.buttons;
import filemanager.client.models.Locator;
import filemanager.client.views.base.LabelButton;
import js.Dom;

/**
 * ...
 * @author valerie.elimak - blog.elimak.com
 */

class RefreshButton extends LabelButton
{
	public static inline var VIEW_ID : String = "RefreshButton";
	public var onRefreshClicked : String->Void;
	
	public function new(label: String, SLPId:String ) 
	{
		Locator.registerSLDisplay(SLPId, this, VIEW_ID);
		super(label, SLPId);
		rootElement.className = "buttons refreshButton";
		onclicked = handleClicked;
		enabled = true;
	}
	
	private function handleClicked( evt: Event ) {
		if (onRefreshClicked != null ) {
			onRefreshClicked("RefreshButton");
		}
	}
}

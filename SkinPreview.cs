using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using System.Collections.Generic;

public sealed class SkinPreview : PictureBox {
    Bitmap fallback;
    float yaw = 0.40f;
    int dragX;
    public void LoadDefault(string path) { fallback = new Bitmap(path); Invalidate(); }
    protected override void OnMouseDown(MouseEventArgs e) { base.OnMouseDown(e);dragX=e.X;Capture=true; }
    protected override void OnMouseUp(MouseEventArgs e) { base.OnMouseUp(e);Capture=false; }
    protected override void OnMouseMove(MouseEventArgs e) {
        base.OnMouseMove(e);
        if(e.Button==MouseButtons.Left){yaw=Math.Max(-0.95f,Math.Min(0.95f,yaw+(e.X-dragX)*0.035f));dragX=e.X;Invalidate();}
    }
    sealed class Face {
        public PointF[] corners; public Rectangle uv, overlay; public float depth;
    }
    protected override void OnPaint(PaintEventArgs e) {
        var atlas = Image as Bitmap ?? fallback;
        if(atlas==null)return;
        var faces = new List<Face>();
        double c=Math.Cos(yaw), s=Math.Sin(yaw);
        float scale=Math.Min(Width/23f,Height/36f);
        Action<float,float,float,int,int,int,int,int,int,int> box = (x,y,z,w,h,d,u,v,ou,ov) => {
            Func<float,float,float,PointF> point=(px,py,pz)=>new PointF(Width/2f+(float)(px*c+pz*s)*scale,2+(py+(float)(px*s-pz*c)*0.18f+1.5f)*scale);
            Action<PointF,PointF,PointF,int,int,int,int,float> face=(a,b,f,tx,ty,tw,th,depth)=>{
                faces.Add(new Face{corners=new[]{a,b,f},uv=new Rectangle(u+tx,v+ty,tw,th),overlay=new Rectangle(ou+tx,ov+ty,tw,th),depth=depth});
            };
            float mid=(float)(-(x+w/2f)*s+(z+d/2f)*c);
            face(point(x,y,z+d),point(x+w,y,z+d),point(x,y+h,z+d),d,d,w,h,mid+(float)c*d/2);
            if(s>=0)face(point(x,y,z),point(x,y,z+d),point(x,y+h,z),0,d,d,h,mid+(float)s*w/2);
            else face(point(x+w,y,z+d),point(x+w,y,z),point(x+w,y+h,z+d),d+w,d,d,h,mid-(float)s*w/2);
            face(point(x,y,z),point(x+w,y,z),point(x,y,z+d),d,0,w,d,mid+0.05f);
        };
        bool modern=atlas.Height>=64;
        box(-4,20,-2,4,12,4,0,16,0,32);box(0,20,-2,4,12,4,modern?16:0,modern?48:16,0,48);
        box(-4,8,-2,8,12,4,16,16,16,32);
        box(-8,8,-2,4,12,4,40,16,40,32);box(4,8,-2,4,12,4,modern?32:40,modern?48:16,48,48);
        box(-4,0,-4,8,8,8,0,0,32,0);
        faces.Sort((a,b)=>a.depth.CompareTo(b.depth));
        e.Graphics.InterpolationMode=InterpolationMode.NearestNeighbor;
        e.Graphics.PixelOffsetMode=PixelOffsetMode.Half;
        foreach(var f in faces){
            e.Graphics.DrawImage(atlas,f.corners,f.uv,GraphicsUnit.Pixel);
            if(f.overlay.Bottom<=atlas.Height)e.Graphics.DrawImage(atlas,f.corners,f.overlay,GraphicsUnit.Pixel);
        }
    }
    int generation;
    string last;
    readonly ToolTip tip = new ToolTip();
    public async void Choose(string name) {
        if (name == last) return;
        last = name;
        int ticket = ++generation;
        var previous = Image;
        Image = null;
        if (previous != null) previous.Dispose();
        if (String.IsNullOrEmpty(name) || !Regex.IsMatch(name, @"^[a-zA-Z0-9_]{3,16}$")) return;
        try {
            Bitmap result = await Task.Run(() => Fetch(name));
            if (IsDisposed || generation != ticket) { result.Dispose(); return; }
            Image = result;
            tip.SetToolTip(this, name);
        } catch { if (!IsDisposed && ticket == generation) tip.SetToolTip(this,"Skin no disponible"); }
    }
    static Bitmap Fetch(string name) {
        var json = new JavaScriptSerializer();
        using (var client = new WebClient()) {
            var user = json.Deserialize<Dictionary<string,object>>(client.DownloadString("https://api.mojang.com/users/profiles/minecraft/"+name));
            string id = (string)user["id"];
            if (!Regex.IsMatch(id, "^[0-9a-fA-F]{32}$")) throw new FormatException();
            var profile = json.DeserializeObject(client.DownloadString("https://sessionserver.mojang.com/session/minecraft/profile/"+id)) as Dictionary<string,object>;
            foreach (Dictionary<string,object> property in (object[])profile["properties"]) {
                if ((string)property["name"] != "textures") continue;
                var payload = json.Deserialize<Dictionary<string,object>>(Encoding.UTF8.GetString(Convert.FromBase64String((string)property["value"])));
                var textures = (Dictionary<string,object>)payload["textures"];
                var skin = (Dictionary<string,object>)textures["SKIN"];
                Uri url = new Uri((string)skin["url"]);
                if (url.Host != "textures.minecraft.net") throw new FormatException();
                using (var stream = new System.IO.MemoryStream(client.DownloadData("https://textures.minecraft.net"+url.AbsolutePath)))
                using (var raw = new Bitmap(stream)) {
                    return new Bitmap(raw);
                }
            }
            throw new FormatException();
        }
    }
    protected override void Dispose(bool disposing) { if(disposing){generation++;tip.Dispose();if(fallback!=null)fallback.Dispose();if(Image!=null)Image.Dispose();} base.Dispose(disposing); }
}

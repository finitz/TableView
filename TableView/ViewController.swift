
import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    struct CellData {
        let url: String
        let name: String
    }

    var cellData = [CellData]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        parseLocalJSON()
        
        let tableView = UITableView(frame: self.view.bounds, style: .plain)
        tableView.register(CustomCell.self, forCellReuseIdentifier: "cellId")
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.dataSource = self
        self.view.addSubview(tableView)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellId") as! CustomCell
        
        config(cell: cell, indexPath: indexPath)
        
        return cell
    }
    
    func config(cell: CustomCell, indexPath: IndexPath) {
        
        let object = cellData[indexPath.row]
        
        let url:String = object.url
        cell.tag = indexPath.row
        cell.textLabel?.text = ""
        let loader = ImageLoader(url: url) { [weak cell] (image) in
            
            if let cell = cell, cell.tag == indexPath.row {
                cell.imageView?.image = image
                cell.textLabel?.text = object.name
            }
        }
        
        cell.setImageLoader(loader: loader)
    }
    
    func parseLocalJSON() {
        
        guard let path = Bundle.main.path(forResource: "mask", ofType: "json") else { return }
        let url = URL(fileURLWithPath: path)
        
        do {
            let data = try Data(contentsOf: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String:String]] {
                for node in json {
                    if let url = node["icon_url"], let id = node["resource_id"] {
                        let cell = CellData(url: url, name: id)
                        cellData.append(cell)
                        
                    }
                }
            }
        } catch { print(error) }
    }
     
}

class CustomCell: UITableViewCell {
    var imageLoader:ImageLoader?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setImageLoader(loader: ImageLoader) {
        imageLoader?.cancel()
        self.imageView?.image = nil
        
        imageLoader = loader
        imageLoader?.load()
    }
}

class ImageLoader {
    var urlString: String!
    var completionBlock: ((UIImage?) -> Void)?
    
    init(url: String, completion: @escaping (UIImage?) -> Void) {
        self.urlString = url
        self.completionBlock = completion
    }
    
    func load() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(downloadComplete),
                                               name: NSNotification.Name.init("download-success"),
                                               object: nil)
        Downloader.shared().download(urlString: self.urlString)
    }
    
    @objc func downloadComplete(note: NSNotification) {
        guard let info = note.userInfo,
            let url = info["url"] as? String,
            url == self.urlString else {return}
                
        let img: UIImage? = info["image"] as? UIImage
        
        if let block = self.completionBlock {
            block(img)
        }
    }
    
    func cancel() {
        NotificationCenter.default.removeObserver(self)
        self.completionBlock = nil
    }
}

class Downloader {
    static let imageDownloader = Downloader()
    var fileManager = FileManager.default
    
    static func shared() -> Downloader {
        return imageDownloader
    }
    
    func download(urlString: String) {
        
        let fileName = urlString.components(separatedBy: "/").last!
        var image = UIImage()
        
        DispatchQueue.global().async {
            
            if self.fileAlreadyExists(name: fileName) {
                image = self.dataFromFile(fileName: fileName)
            } else {
                let data = try! Data(contentsOf: URL(string: urlString)!)
                
                image = UIImage(data: data)!
                self.writeIntoFileDirectory(image: image, fileName: fileName)
            }
            
            DispatchQueue.main.async {
            var info = [String:Any]()
            info["image"] = image
            info["url"] = urlString
            NotificationCenter.default.post(name: NSNotification.Name.init("download-success"),
                                            object: nil,
                                            userInfo: info)
            }
            
        }
    }

    func writeIntoFileDirectory(image: UIImage, fileName: String) {
        do {
            let documentsDirectory = try fileManager.url(for: .documentDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor:nil,
                                                         create:false)
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            let imageData = image.jpegData(compressionQuality: 1)
            try imageData?.write(to: fileURL)
        }
        catch {
            print(error)
        }
    }

    func fileAlreadyExists(name fileName: String) -> Bool {
        let documentsDirectory = try! fileManager.url(for: .documentDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor:nil,
                                                      create:false)
        let filePath = documentsDirectory.appendingPathComponent(fileName).path
        
        return fileManager.fileExists(atPath: filePath)
    }
    
    func dataFromFile(fileName: String) -> UIImage {

            let documentsDirectory = try! fileManager.url(for: .documentDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor:nil,
                                                         create:false)
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            let image = UIImage(data: try! Data(contentsOf: fileURL))
            return image!
    }

}


    



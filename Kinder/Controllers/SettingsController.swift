//
//  SettingsController.swift
//  Kinder
//
//  Created by Kenny Ho on 1/30/19.
//  Copyright © 2019 Kenny Ho. All rights reserved.
//

import UIKit
import Firebase
import JGProgressHUD
import SDWebImage

protocol SettingsControllerDelegate: class {
    func didSaveSettings()
}

class CustomImagePickerController: UIImagePickerController {
    var imageButton: UIButton?
}

class SettingsController: UITableViewController {

    weak var delegate: SettingsControllerDelegate?
    
    //Instance Properties
    var user: User?
    lazy var image1Button = createButton(selector: #selector(handleSelectPhoto))
    lazy var image2Button = createButton(selector: #selector(handleSelectPhoto))
    lazy var image3Button = createButton(selector: #selector(handleSelectPhoto))
    
    //Helper Function
    func createButton(selector: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Select Photo", for: .normal)
        button.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        button.addTarget(self, action: selector, for: .touchUpInside)
        button.imageView?.contentMode = .scaleAspectFill
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        return button
    }
    
    lazy var header: UIView = {
        let header = UIView()
        
        header.addSubview(image1Button)
        let padding: CGFloat = 16
        image1Button.anchors(top: header.topAnchor, leading: header.leadingAnchor, bottom: header.bottomAnchor, trailing: nil, padding: .init(top: padding, left: padding, bottom: padding, right: padding))
        image1Button.widthAnchor.constraint(equalTo: header.widthAnchor, multiplier: 0.45).isActive = true
        
        let stackView = UIStackView(arrangedSubviews: [image2Button, image3Button])
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = padding
        
        header.addSubview(stackView)
        stackView.anchors(top: header.topAnchor, leading: image1Button.trailingAnchor, bottom: header.bottomAnchor, trailing: header.trailingAnchor, padding: .init(top: padding, left: padding, bottom: padding, right: padding))
        return header
    }()
    
    //MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationItem()
        tableView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        tableView.tableFooterView = UIView()
        tableView.keyboardDismissMode = .interactive
        fetchCurrentUser()
    }
    
    //MARK: - Fileprivate Methods
    fileprivate func fetchCurrentUser() {
        //Fetch Firestore Data
        Firestore.firestore().fetchCurrentUser { (user, err) in
            if let err = err {
                print("Failed to fetch user:", err)
                return
            }
            
            //fetch User
            self.user = user
            self.loadUserPhotos()
            self.tableView.reloadData()
        }
    }
    
    fileprivate func loadUserPhotos() {
        if let imageUrl = user?.imageUrl1, let url = URL(string: imageUrl) {
            SDWebImageManager.shared().loadImage(with: url, options: .continueInBackground, progress: nil) { (image, _, _, _, _, _) in
                self.image1Button.setImage(image?.withRenderingMode(.alwaysOriginal), for: .normal)
            }
        }
        
        if let imageUrl = user?.imageUrl2, let url = URL(string: imageUrl) {
            SDWebImageManager.shared().loadImage(with: url, options: .continueInBackground, progress: nil) { (image, _, _, _, _, _) in
                self.image2Button.setImage(image?.withRenderingMode(.alwaysOriginal), for: .normal)
            }
        }
        
        if let imageUrl = user?.imageUrl3, let url = URL(string: imageUrl) {
            SDWebImageManager.shared().loadImage(with: url, options: .continueInBackground, progress: nil) { (image, _, _, _, _, _) in
                self.image3Button.setImage(image?.withRenderingMode(.alwaysOriginal), for: .normal)
            }
        }
    }
    
    fileprivate func setupNavigationItem() {
        navigationItem.title = "Settings"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(handleCancel))
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(handleSave)),
            UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(handleLogout))
        ]
    }
    
    @objc fileprivate func handleLogout() {
        try? Auth.auth().signOut()
        dismiss(animated: true, completion: nil)
    }
    
    @objc fileprivate func handleSelectPhoto(button: UIButton) {
        print("Selecting photo using \(#function) from line \(#line)")
        let imagePicker = CustomImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.imageButton = button
        present(imagePicker, animated: true, completion: nil)
    }
    
    @objc fileprivate func handleSave() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let docData: [String: Any] = [
            "uid": uid,
            "fullName": user?.name ?? "",
            "imageUrl1": user?.imageUrl1 ?? "",
            "imageUrl2": user?.imageUrl2 ?? "",
            "imageUrl3": user?.imageUrl3 ?? "",
            "age": user?.age ?? -1,
            "profession": user?.profession ?? "",
            "minSeekingAge": user?.minSeekingAge ?? -1,
            "maxSeekingAge": user?.maxSeekingAge ?? -1
        ]
        
        let hud = JGProgressHUD(style: .dark)
        hud.textLabel.text = "Saving settings"
        hud.show(in: view)
        
        Firestore.firestore().collection("users").document(uid).setData(docData) { (err) in
            hud.dismiss()
            
            if let err = err {
                print("Failed to save user settings", err)
                return
            }
            
            print("Finish saving user info")
            self.dismiss(animated: true, completion: {
                print("Dismissal complete")
                self.delegate?.didSaveSettings()
            })
        }
    }
    
    @objc fileprivate func handleCancel() {
        dismiss(animated: true, completion: nil)
    }
    
    class HeaderLabel: UILabel {
        override func drawText(in rect: CGRect) {
            super.drawText(in: rect.insetBy(dx: 16, dy: 0))
        }
    }
    
    @objc fileprivate func handleMinAgeChange(slider: UISlider) {
        //Update minLabel in AgeRangeCell
        evaluateMinMax()
    }
    
    @objc fileprivate func handleMaxAgeChange(slider: UISlider) {
        evaluateMinMax()
    }
    
    fileprivate func evaluateMinMax() {
        let indexPath = IndexPath(row: 0, section: 5)
        guard let ageRangeCell = tableView.cellForRow(at: indexPath) as? AgeRangeCell else { return }
        let minValue = Int(ageRangeCell.minSlider.value)
        var maxValue = Int(ageRangeCell.maxSlider.value)
        maxValue = max(minValue, maxValue)
        
        ageRangeCell.maxSlider.value = Float(maxValue)
        ageRangeCell.minLabel.text = "Min \(minValue)"
        ageRangeCell.maxLabel.text = "Max \(maxValue)"
        
        user?.minSeekingAge = minValue
        user?.maxSeekingAge = maxValue
    }

    //MARK: - Tableview Datasource
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            return header
        }
        
        let headerLabel = HeaderLabel()
        
        switch section {
        case 1: headerLabel.text = "Name"
        case 2: headerLabel.text = "Profession"
        case 3: headerLabel.text = "Age"
        case 4: headerLabel.text = "Bio"
        default: headerLabel.text = "Seeking Age Range"
        }
        
        headerLabel.font = UIFont.boldSystemFont(ofSize: 16)
        return headerLabel
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        if section == 0 {
            return 300
        }
        
        return 40
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 6
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //If section == 0, return 0 rows, otherwise return 1 row
        return section == 0 ? 0 : 1
    }
    
    static let defaultMinSeekingAge = 18
    static let defaultMaxSeekingAge = 50
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        //Age Range Cell
        if indexPath.section == 5 {
            let ageRangeCell = AgeRangeCell(style: .default, reuseIdentifier: nil)
            ageRangeCell.minSlider.addTarget(self, action: #selector(handleMinAgeChange), for: .valueChanged)
            ageRangeCell.maxSlider.addTarget(self, action: #selector(handleMaxAgeChange), for: .valueChanged)
            
            //Set up labels on cell
            let minAge = user?.minSeekingAge ?? SettingsController.defaultMinSeekingAge
            let maxAge = user?.maxSeekingAge ?? SettingsController.defaultMaxSeekingAge
            
            ageRangeCell.minLabel.text = "Min \(minAge)"
            ageRangeCell.maxLabel.text = "Max \(maxAge)"
            ageRangeCell.minSlider.value = Float(minAge)
            ageRangeCell.maxSlider.value = Float(maxAge)
            return ageRangeCell
        }
        
        let cell = SettingsCell(style: .default, reuseIdentifier: nil)
        
        switch indexPath.section {
        case 1:
            cell.textField.placeholder = "Enter Name"
            cell.textField.text = user?.name
            cell.textField.addTarget(self, action: #selector(handleNameChange), for: .editingChanged)
        case 2:
            cell.textField.placeholder = "Enter Profession"
            cell.textField.text = user?.profession
            cell.textField.addTarget(self, action: #selector(handleProfessionChange), for: .editingChanged)
        case 3:
            cell.textField.placeholder = "Enter Age"
            if let age = user?.age {
                cell.textField.text = String(age)
                cell.textField.addTarget(self, action: #selector(handleAgeChange), for: .editingChanged)
            }
        default:
            cell.textField.placeholder = "Enter Bio"
        }
        
        return cell
    }
    
    @objc fileprivate func handleNameChange(textField: UITextField) {
        self.user?.name = textField.text
    }
    
    @objc fileprivate func handleProfessionChange(textField: UITextField) {
        self.user?.profession = textField.text
    }
    
    @objc fileprivate func handleAgeChange(textField: UITextField) {
        self.user?.age = Int(textField.text ?? "")
    }
    
}

//MARK: - ImagePicker Delegate
extension SettingsController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        var image: UIImage?
        
        if let editedImage = info[.editedImage] as? UIImage {
            image = editedImage
        } else {
            let selectedImage = info[.originalImage] as? UIImage
            image = selectedImage
        }
        
        let imageButton = (picker as? CustomImagePickerController)?.imageButton
        imageButton?.setImage(image?.withRenderingMode(.alwaysOriginal), for: .normal)
        dismiss(animated: true, completion: nil)
        
        let hud = JGProgressHUD(style: .dark)
        hud.textLabel.text = "Uploading image..."
        hud.show(in: view)
        
        let filename = UUID().uuidString
        let ref = Storage.storage().reference(withPath: "/images/\(filename)")
        guard let uploadedData = image?.jpegData(compressionQuality: 0.75) else { return }
        ref.putData(uploadedData, metadata: nil) { (nil, err) in
            
            if let err = err {
                hud.dismiss()
                print("Failed to upload image to Storage:", err)
                return
            }
            
            print("Uploading image successful")
            ref.downloadURL(completion: { (url, err) in
                hud.dismiss()
                
                if let err = err {
                    print("Failed to retrieve download URL:", err)
                    return
                }
                
                print("Finish getting download url for image:", url?.absoluteString ?? "")
                
                if imageButton == self.image1Button {
                    self.user?.imageUrl1 = url?.absoluteString
                } else if imageButton == self.image2Button {
                    self.user?.imageUrl2 = url?.absoluteString
                } else {
                    self.user?.imageUrl3 = url?.absoluteString
                }
            })
        }
    }
}

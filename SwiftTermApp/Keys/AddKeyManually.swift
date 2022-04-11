//
//  AddKeyView.swift
//
//  Used to paste an SSH public/private key and store it
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct EditKey: View {
    @ObservedObject var store: DataStore = DataStore.shared
    @Binding var addKeyManuallyShown: Bool
    var _key: Key
    @State var disableChangePassword = false
    @State var showingPassword = false
    
    @State var type: KeyType = .rsa(4096)
    @State var name: String = ""
    @State var privateKey: String = ""
    @State var publicKey: String = ""
    @State var passphrase: String = ""
    @State var keyTag: String = ""
    
    public init (addKeyManuallyShown: Binding<Bool>, key: Key, disableChangePassword: Bool)
    {
        self._key = key
        self._addKeyManuallyShown = addKeyManuallyShown
        self.disableChangePassword = disableChangePassword
        
        _name = State (initialValue: key.name)
        _type = State (initialValue: key.type)
        _privateKey = State (initialValue: key.privateKey)
        _publicKey = State (initialValue: key.publicKey)
        _passphrase = State (initialValue: key.passphrase)
        _keyTag = State (initialValue: key.keyTag)
    }
    
    var privateKeyComplete: Bool {
        return privateKey.contains ("BEGIN") && privateKey.contains ("END") && privateKey.contains ("PRIVATE KEY")
    }
    
    var disableSave: Bool {
        name == "" || !privateKeyComplete
    }
    
    func saveAndLeave ()
    {
        _key.name = name
        _key.type = type
        _key.privateKey = privateKey
        _key.publicKey = publicKey
        _key.passphrase = passphrase
        _key.keyTag = keyTag
        store.save (key: self._key)
        addKeyManuallyShown = false
    }
    
    // Tries to do something smart for adding the key by default
    func setupKey ()
    {
        // Maybe the clipboard has a key
        let clip = UIPasteboard.general
        if clip.hasStrings {
            if let value = clip.string {
                if value.contains("BEGIN OPENSSH PRIVATE KEY") {
                    privateKey = value
                } else if value.starts(with: "ssh-rsa") || value.starts(with: "ssh-dss") || value.starts(with: "ecdsa-sha2-nistp256") || value.starts(with: "ssh-ed25519") {
                    publicKey = value
                }
            }
        }
    }
    
    struct Footer: View {
        var body: some View {
            Text ("Clicking on the file selector icons allows you to use Files to select your private and public keys.\n\nThe private key is required, and if it needs a passphrase, you will need to provide it")
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section (footer: Footer()) {
                    VStack {
                        HStack {
                            Text ("Name")
                            Spacer ()
                        }
                        TextField ("Required", text: $name)
                    }
                    HStack {
                        Text ("Type")
                        Spacer ()
                        Text (type.description)
                            .foregroundColor(Color (.systemGray))
                    }
                    if case .ecdsa(inEnclave: true) = type {
                        
                    } else {
                        Passphrase(passphrase: $passphrase, disabled: disableChangePassword)
                        VStack {
                            HStack {
                                Text ("Private Key")
                                Spacer ()
                                if !privateKeyComplete {
                                    Text ("Required")
                                        .foregroundColor(.red)
                                }
                                ContentsFromFile (target: $privateKey)
                            }
                            HStack {
                                TextEditor(text: $privateKey)
                                    //.frame(height: 80)
                                    .frame(minHeight: 80, maxHeight: 220)
                                    .lineLimit(20)
                                    .autocapitalization(.none)
                                    //.font(.custom("Menlo", fixedSize: 8.5))
                                    .font(.system(size: 8, weight: .light, design: .monospaced))
                            }
                        }
                    }
                    VStack {
                        HStack {
                            Text ("Public Key")
                            Spacer ()
                            ContentsFromFile (target: $publicKey)
                        }
                        HStack {
                            TextEditor (text: $publicKey)
                                .frame(minHeight: 80, maxHeight: 220)
                                .lineLimit(20)
                                .autocapitalization(.none)
                                .font(.system(size: 8, weight: .light, design: .monospaced))
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .toolbar {
                ToolbarItem (placement: .navigationBarLeading) {
                    Button ("Cancel") { self.addKeyManuallyShown = false }
                }
                ToolbarItem (placement: .navigationBarTrailing) {
                    Button("Save") { self.saveAndLeave() }
                        .disabled (disableSave)

                }
            }

        }.onAppear {
            self.setupKey ()
        }
    }
}

var sampleKey = Key(id: UUID(),
                    type: .rsa(1024),
                    name: "Sample Key",
                    privateKey:
                                   """
                                      -----BEGIN OPENSSH PRIVATE KEY-----
                                      b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABB2LUMKCJ
                                      kNl81rKVpz877uAAAAEAAAAAEAAAGXAAAAB3NzaC1yc2EAAAADAQABAAABgQCeW0V0zStj
                                      hsFGntgp7Sexiq4jcofPFvm7lrT563mquimGgPnL5m7PRwyL1+vYPTt3UdCVjITjssLt3W
                                      NswomHSO6S9ArvWvJoZHdCY3JeqZDZlZe2RhwCyvW0gboabWCjpZxNXHm35WpFEJbrUfsI
                                      sykoEQegpx1o/NUtIxNpI8YJT6ZEahzAHHHofjigq3t4NdC6OjvH7YdiGFk8OQdMc1r3Kt
                                      knLq/c38raYz8L3x4eM/KoDvZYMx8iz7x7N4Piv/O+u0BHbsLRD2ruVi3CAkfVwY1sT+Tq
                                      1rLmo3OhGVrH9nJcr8JJrUFfgjDbFjE4xroyMvunlEMIyP0S1SGJaU2QrrO3vqSKk2DP96
                                      n6UvwHjB5iTpaadLR5hps+kMij+m7JHSQ5Xu5T2vRAimL5uJ6hJRLVmBTlPohMeh54enxU
                                      b8yvyghMNVrkj7O0PgjvFYRAwm7aGODkkHdrGXpgTTESobo8uquLVqtdh+qEodkjqICk1a
                                      J98625ymfbWRsAAAWg51jsCSAyiv4zsCjdjcxpqg72e8KMPYCXWWxvQSne9HoxAH5SkPr4
                                      Av53rZ0GRNK41GId+83Xj9ZPubkdszjKi1f5DIeyEQor/6+aGG8zFPRk2b8qxXYouPtNBr
                                      Vbl1Cf0u2+ERsZrs5E5Mu2ryvjo8HP2vhKD/aO/z1GI8RkHRoBB27TSIrQEc/zmQTXulmo
                                      8+2kqVaWHUJNbakXSkMxtoRy3nHKOpW19hYr//oOQjhJfjj/jA1CoqHobRUzKRqckF0Yng
                                      x6cC11ut/zZp1u0llsikbwYgkXTvJrVSdhb04e390rt64tq6SttAr8EIIZO412z4G/OMu5
                                      iDHlmI3x2nAG5BebMi3g4KJDmyLf8/8dFzGaWigGvuZWqGB7f3gcm0DTHbAlg3il9IMj0Z
                                      QL1Y6hVoCoyapsOMNtsMsO7qkK7jfleida3t/4FcvHstwSOLDeBjGMeVZUcyi6LXmM5L0q
                                      +Iu2NqrensEN+uYiE732OhdcDh7RCRdZygd5TRj4VegpF/BMmyslggVzfzm8pwn2Tl6Ej8
                                      KrfwSqqAWN53DJphtSc1maqMcBs/zL3VZXhFPugyRDODfRGsj9skmJD05pkSxARxsUeI95
                                      Hnl5mUtUx/ccEYqlUHQF5zj+Z4mIlOxZ2tu/mFvzy5E3CroxeTkZXPOjREL3Z0K2Uk3sUd
                                      4NxhlNap6TWKTjW1jYMOXq56QKtya9SbfAR/KGSXHnwJnKqnaLhcdiN+xdoGpWhX4KRhsj
                                      TfseOfD0LIerP1hlRu5EkEd6CL/1AuvMpSvIAH77oSxF6BAaiWZqxvQehoJFgU1ZJIPCfO
                                      saz5Izwl8LtBnMjNolkANvuutmyf5k1x56o3wO6sG+d5I/D3Set/959rz85aw4ySpq3hFm
                                      Y37uVk5xUPQ8rIHbIhKBed3YfNhdbTGq1sSVGzHnH18E45SScr6XK1M002NekuZRlFosRW
                                      UEKjjKq7XX23+gLi5llnGUfShvKZr0dmhvTLATR4F8Wq4gLElqXeTucfvPw9mgxTI6ONvQ
                                      vfevKQRhkmrX/yLntU/Nhctxn5atcNaSaclVuOSrUM0xysXv6vKhTN1Mbef8YkwT6uUKAC
                                      6OP6koobg19ZAz7tVzM0Dh93lfUqu6gbvYBZ29ADwze70d01lYLxoFLue4lLHkpT+sIJ+N
                                      OyszhNyUwVRHMNx4g/SWRf7TBHekwkpe4ODDYykxNu1VNSMscE0pODkYlkqj44sypOcKWe
                                      olud5r3U4QMVspbnrUwbQaba+bqfXV3DVh1s57+uLG9jrkgDFx4YXiE4Q5Y1AH1QbTx3Jp
                                      U1HzkSENSbmtFmUPjlh4emVUFTvUgwmVdjXU1/8MRK09CpnetxLmUE8/uP2KII5Ruqz2Xx
                                      TQZAYBzm+dAxJIpjcmVN//GZel7J7U0XlLOcfViSfPbnR+55f+jsvY4zf182rMS7yujDQd
                                      Cqeymp9WPDX3VuvbJd4U/q4lG6RFY4udaE/1yIfV/KiviKIEfjkMd3mReomNug3rLce/HK
                                      m0NTxz58oE8Q/kEi2qKjZbcO+Soh02KhsCqws06bZiQdnJhGgViVdoobOPhgWHq20ZeKMf
                                      bdboDR38H5jdWDB0aqq6oUgg64cNdtKqQnQcacaP15kDcXgZM+ugEdoxI3q9QSW711Ddvh
                                      gpP2g++xIbrpdzhEMS4BdDtlFgq1qoak7O3bxRXRydgisyiJrwYfV5At8yUMHenEgKR5iP
                                      bQqD33RP43l7qhduhTBG6tPmyHfQQ1TdhuaChvr/bOIrZQ+dx+Dt0ryUmkYHpqsvntH23Q
                                      GEJZKnWJTggyxn4zYxfeqLQ5XU0axnQULoxIL4q70EVCEEeHj57ZIxQ9FKZ3pYpVUSYwei
                                      3vVROJPJfraMiFxyTn4cR91z/ElYyVuZisqFDJ6i9dAHMRAL
                                      -----END OPENSSH PRIVATE KEY-----
                                      """,
                    publicKey: "",
                    passphrase: "")
//
// Implements adding a new Key from pasted data
struct AddKeyManually: View {
    @State var key: Key
    @Binding var addKeyManuallyShown: Bool
    
    var body: some View {
        EditKey(addKeyManuallyShown: $addKeyManuallyShown, key: key, disableChangePassword: false)
    }
}

struct PasteKey_Previews: PreviewProvider {
    static var previews: some View {
        AddKeyManually(key: sampleKey, addKeyManuallyShown: .constant(true))
    }
}

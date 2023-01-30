//
//  AppListViewModel.swift
//  Applist
//
//  Created by wulei7 on 2023/1/29.
//

import Alamofire
import Foundation

let searchUrl = "https://itunes.apple.com/search"

class AppListViewModel: ObservableObject {
    let pageSize = 20 // 每页20条，page增加时，改变接口的limit = （page+1）* pageSize
    var page = 0 // 当前page,因接口限制，无法直接使用，每次加载的数据为（page+1）*pageSize条（即为limit），若resultData.resultCount < limit,则表示加载完毕。为了简单起见，默认请求时前面每一页的数据都相同，loadmore的时候，直接替换全部内容，而不是遍历去重然后增加剩下的
    @Published var resultData: Optional<ResponseModel> = nil // 所有数据

    @Published var firstLoad = true // 是否首次加载，决定是否展示全屏loading
    @Published var isLoading = false // 是否正在加载更多
    @Published var loadAll = false // 是否全部加载完毕
    @Published var loadError: AFError? = nil // 是否加载失败

    @Published var likedList: [AppModel] = [] // 喜欢的数组，因视频中并未出现重启的情况，故此处并未做保存到本地的操作

    init(page: Int) {
        self.page = page
    }

    func toggleLikedData(appModel: AppModel) {
        if resultData?.results.count ?? 0 <= 0 {
            return
        }
        if let firstMatch = likedList.first(where: { $0.trackId == appModel.trackId }) {
            likedList.removeAll(where: { $0.trackId == firstMatch.trackId })
        } else {
            likedList.append(appModel)
        }
    }

    /**
     下拉刷新
     注：如果正在刷新的时候，上拉或下拉，不做任何处理，避免page逻辑混乱
     */
    public func refresh() {
        if isLoading {
            return
        }
        page = 0
        loadAll = false
        fetchSearchData(page: page, refresh: true)
    }

    /**
     上拉加载更多
     */
    public func loadMore() {
        if isLoading {
            return
        }
        page += 1
        isLoading = true
        fetchSearchData(page: page, refresh: false)
    }

    /**
        注：鉴于此处只有一个请求，故网络请求方面并没有使用SessionManager的单例来发送请求，也未设置headers，cookies等东西，实际项目网络库比较复杂，故此处并未作过多处理
        page：当前页面序号
        refresh: 是否是下拉刷新，如果是，加载失败不用处理，如果否，加载失败，self.page需要--
     */
    private func fetchSearchData(page: Int, refresh: Bool) {
        let params: [String: Any] = [
            "entity": "software",
            "limit": (page + 1) * pageSize,
            "term": "chat",
            "page": page,
        ]
        print("______page:\(page)")
        AF.request(searchUrl, method: .get, parameters: params, encoding: URLEncoding() as ParameterEncoding, headers: nil, interceptor: nil, requestModifier: nil).responseDecodable(of: ResponseModel.self) { response in
            self.firstLoad = false
            self.isLoading = false
            switch response.result {
            case let .success(data):
                print("______data:\(data)")
                self.loadError = nil
                self.resultData = data
                // 多请求一次，才能知道是否加载完毕。未加载完毕之前，data.resultCount 必定等于(self.page + 1) * self.pageSize
                if data.resultCount < (self.page + 1) * self.pageSize {
                    self.loadAll = true
                }
                break
            case let .failure(error):
                self.loadError = error
                if self.page > 0 {
                    self.page -= 1
                }
                break
            }
        }
    }
}
